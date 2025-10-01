import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.vcs

/*
The settings script is an entry point for defining a TeamCity
project hierarchy. The script should contain a single call to the
project() function with a Project instance or an init function as
an argument.

VcsRoots, BuildTypes, Templates, and subprojects can be
registered inside the project using the vcsRoot(), buildType(),
template(), and subProject() methods respectively.

To debug settings scripts in command-line, run the

    mvnDebug org.jetbrains.teamcity:teamcity-configs-maven-plugin:generate

command and attach your debugger to the port 8000.

To debug in IntelliJ Idea, open the 'Maven Projects' tool window (View
-> Tool Windows -> Maven Projects), find the generate task node
(Plugins -> teamcity-configs -> teamcity-configs:generate), the
'Debug' option is available in the context menu for the task.
*/

version = "2024.03"

project {

    buildType(Tunefy)
}

object Tunefy : BuildType({
    name = "Tunefy"

    params {
        param("env.DOCKER_REGISTRY", "365074502389.dkr.ecr.us-east-1.amazonaws.com")
        param("env.COLOR_NEXT", "blue")
        param("env.AWS_DEFAULT_REGION", "us-east-1")
        password("env.OCTO_API_KEY", "credentialsJSON:223c7874-6618-4f07-b353-809e4ca77e0e")
        param("env.OCTO_URL", "http://10.20.62.98:8080")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "Generate Version"
            id = "Generate_Version"
            scriptContent = """
                # Generar versión basada en Git (alternativa simple a GitVersion)
                VERSION=${'$'}(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
                BUILD_NUMBER=${'$'}(git rev-list --count HEAD)
                COMMIT_SHORT=${'$'}(git rev-parse --short HEAD)
                
                # Formato: version.buildnumber-commit (ej: 1.0.0.123-a1b2c3d)
                DOCKER_TAG="${'$'}{VERSION}.${'$'}{BUILD_NUMBER}-${'$'}{COMMIT_SHORT}"
                
                echo "Generated version: ${'$'}DOCKER_TAG"
                echo "##teamcity[setParameter name='env.DOCKER_TAG' value='${'$'}DOCKER_TAG']"
            """.trimIndent()
        }
        script {
            name = "Login ECR"
            id = "Login_ECR"
            scriptContent = """
                # Usar IAM Role de la instancia EC2 (tunefy-dev-teamcity)
                # El contenedor hereda las credenciales del metadata endpoint
                ECR_PASSWORD=${'$'}(docker run --rm \
                  --network host \
                  -e AWS_DEFAULT_REGION="${'$'}AWS_DEFAULT_REGION" \
                  amazon/aws-cli:2.15.10 \
                  ecr get-login-password --region "${'$'}AWS_DEFAULT_REGION")
                
                echo "${'$'}ECR_PASSWORD" | docker login --username AWS --password-stdin "${'$'}DOCKER_REGISTRY"
            """.trimIndent()
        }
        script {
            name = "Build+Push FRONTEND"
            id = "Build_Push_FRONTEND"
            scriptContent = """
                FRONT="${'$'}DOCKER_REGISTRY/tunefy-frontend-dev:${'$'}DOCKER_TAG"
                docker build -t "${'$'}FRONT" -f frontend/Dockerfile frontend
                docker push "${'$'}FRONT"
            """.trimIndent()
        }
        script {
            name = "Build+Push BACKEND"
            id = "Build_Push_BACKEND"
            scriptContent = """
                BACK="${'$'}DOCKER_REGISTRY/tunefy-backend-dev:${'$'}DOCKER_TAG"
                docker build -t "${'$'}BACK" -f backend/Dockerfile backend
                docker push "${'$'}BACK"
            """.trimIndent()
        }
        script {
            name = "Package Helm Charts for Octopus"
            id = "Package_Helm_Charts"
            scriptContent = """
                echo "Packaging Helm charts for Octopus..."
                
                # Crear directorio temporal para el paquete
                mkdir -p /tmp/charts-package/charts
                
                # Copiar los charts
                cp -r charts/frontend /tmp/charts-package/charts/
                cp -r charts/backend /tmp/charts-package/charts/
                
                # Crear el archivo zip
                cd /tmp/charts-package
                zip -r charts.${'$'}DOCKER_TAG.zip charts/
                
                # Subir a Octopus usando el API
                echo "Uploading charts package to Octopus..."
                curl -X POST "${'$'}OCTO_URL/api/packages/raw" \
                  -H "X-Octopus-ApiKey: ${'$'}OCTO_API_KEY" \
                  -F "data=@charts.${'$'}DOCKER_TAG.zip" \
                  -F "overwriteMode=OverwriteExisting"
                
                echo "Charts package uploaded successfully"
            """.trimIndent()
        }
        script {
            name = "Octopus: create & deploy release (a Dev)"
            id = "Octopus_create_deploy_release_a_Dev"
            scriptContent = """
                SPACE="Default"
                PROJECT="Tunefy"
                REL="${'$'}DOCKER_TAG"
                ENV="Dev"
                COLOR_NEXT="${'$'}{COLOR_NEXT:-blue}"  # alterna en cada build si quieres
                GIT_BRANCH="${'$'}(git rev-parse --abbrev-ref HEAD)"  # Branch actual (develop, main, etc)
                
                echo "Creating Octopus release ${'$'}REL from branch ${'$'}GIT_BRANCH"
                
                # Usar --network host para alcanzar Octopus server en la red privada
                # --gitRef es requerido para proyectos con Version Control
                docker run --rm --network host \
                  -v "${'$'}PWD:/repo" -w /repo \
                  octopusdeploy/octo:9.1.7 \
                  create-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                  --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" \
                  --gitRef "${'$'}GIT_BRANCH" --ignoreExisting \
                  --variable "ColorNext:${'$'}COLOR_NEXT"
                
                if [ ${'$'}? -eq 0 ]; then
                    echo "Release created successfully, deploying..."
                    docker run --rm --network host \
                      octopusdeploy/octo:9.1.7 \
                      deploy-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                      --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" \
                      --deployTo "${'$'}ENV" --progress --waitForDeployment
                else
                    echo "Failed to create release"
                    exit 1
                fi
            """.trimIndent()
        }
    }

    triggers {
        vcs {
        }
    }
})

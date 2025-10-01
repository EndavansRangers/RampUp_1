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
        param("env.DOCKER_TAG", "%GitVersion.SemVer%")
        param("GitVersion.SemVer", "1.0.0")
        param("env.AWS_DEFAULT_REGION", "us-east-1")
        password("env.OCTO_API_KEY", "credentialsJSON:223c7874-6618-4f07-b353-809e4ca77e0e")
        param("env.OCTO_URL", "http://10.20.62.98:8080")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    features {
        feature {
            type = "JetBrains.GitVersion"
            param("versionFormat", "%GitVersion.SemVer%")
        }
    }

    steps {
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
            name = "Octopus: create & deploy release (a Dev)"
            id = "Octopus_create_deploy_release_a_Dev"
            scriptContent = """
                SPACE="Default"
                PROJECT="Tunefy"
                REL="${'$'}DOCKER_TAG"
                ENV="Dev"
                COLOR_NEXT="${'$'}{COLOR_NEXT:-blue}"  # alterna en cada build si quieres
                
                docker run --rm octopusdeploy/octo:9.1.7 \
                  create-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                  --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" --ignoreExisting \
                  --variable "ColorNext:${'$'}COLOR_NEXT"
                
                docker run --rm octopusdeploy/octo:9.1.7 \
                  deploy-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                  --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" \
                  --deployTo "${'$'}ENV" --progress --waitForDeployment
            """.trimIndent()
        }
    }

    triggers {
        vcs {
        }
    }
})

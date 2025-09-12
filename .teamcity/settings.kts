import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildSteps.script

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

version = "2025.07"

project {

    buildType(Tunefy)
}

object Tunefy : BuildType({
    name = "Tunefy"

    params {
        param("env.DOCKER_REGISTRY", "10.20.0.150:5000")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "GitVersion"
            id = "GitVersion"
            scriptContent = """
                docker run --rm -v "%teamcity.build.checkoutDir%:/repo" -w /repo \
                  gittools/gitversion:5.12.0-linux /repo /output buildserver
                
                # Opcional: mostrar la versión calculada
                echo "##teamcity[message text='GitVersion: %GitVersion.SemVer%']"
                echo "##teamcity[buildNumber '%GitVersion.SemVer%']"
            """.trimIndent()
        }
        script {
            name = "Backend: deps"
            id = "Backend_deps"
            scriptContent = """
                CHECKOUT="%teamcity.build.checkoutDir%"
                HOST_BACKEND="${'$'}CHECKOUT/backend"
                
                # Instala deps y corre tests en contenedor Node
                tar -C "${'$'}HOST_BACKEND" -cf - . \
                | docker run --rm -i -w /app -e CI=true node:18-alpine sh -lc '
                  set -eu
                  tar -xf - -C /app
                  npm ci
                '
            """.trimIndent()
        }
        script {
            name = "Backend: build Docker + push"
            id = "Backend_build_Docker_push"
            scriptContent = """
                CHECKOUT="%teamcity.build.checkoutDir%"
                REG="%env.DOCKER_REGISTRY%"
                VER="%GitVersion.SemVer%"
                
                docker build -t "${'$'}REG/tunefy/backend:${'$'}VER" -f "${'$'}CHECKOUT/backend/Dockerfile" "${'$'}CHECKOUT/backend"
                docker push "${'$'}REG/tunefy/backend:${'$'}VER"
                echo "##teamcity[buildStatus text='Pushed backend:${'$'}VER']"
            """.trimIndent()
        }
    }
})

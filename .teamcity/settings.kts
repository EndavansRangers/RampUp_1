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

version = "2025.07"

project {

    buildType(Tunefy)
}

object Tunefy : BuildType({
    name = "Tunefy"

    params {
        param("env.DOCKER_REGISTRY", "10.20.0.150:5000")
        param("GitVersion.SemVer", "1.1.0")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "GitVersion"
            id = "GitVersion"
            enabled = false
            scriptContent = """
                BR="${'$'}{env.GIT_BRANCH:-}"
                [ -n "${'$'}BR" ] && git -C "${'$'}CLONE" checkout "${'$'}BR" || true
            """.trimIndent()
        }
        script {
            name = "borrar"
            id = "borrar"
            scriptContent = """
                set -eu
                
                CHECKOUT="%teamcity.build.checkoutDir%"
                ls -la "${'$'}CHECKOUT/.git" || { echo "Falta .git en ${'$'}CHECKOUT"; exit 2; }
                
                # Calcula SemVer DENTRO del contenedor y lo devuelve por stdout
                SEMVER=${'$'}(
                  tar -C "${'$'}CHECKOUT" -cf - . \
                  | docker run --rm -i mcr.microsoft.com/dotnet/sdk:8.0-alpine sh -lc '
                      set -e
                      apk add --no-cache git >/dev/null
                      mkdir -p /repo
                      tar -xf - -C /repo
                      git config --global --add safe.directory /repo
                      dotnet tool install -g GitVersion.Tool --version 5.12.0 >/dev/null
                      ~/.dotnet/tools/dotnet-gitversion /repo /showvariable SemVer
                    '
                )
                
                echo "GitVersion.SemVer calculado: ${'$'}SEMVER"
                
                # Publica para el resto de steps (sin placeholders de TeamCity)
                echo "##teamcity[setParameter name='env.DOCKER_TAG' value='${'$'}SEMVER']"
                echo "##teamcity[buildNumber '${'$'}SEMVER']"
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
        script {
            name = "Frontend: build"
            id = "Frontend_build"
            scriptContent = """
                CHECKOUT="%teamcity.build.checkoutDir%"
                HOST_FRONTEND="${'$'}CHECKOUT/frontend"
                
                tar -C "${'$'}HOST_FRONTEND" -cf - . \
                | docker run --rm -i -w /app \
                  node:18-alpine sh -lc '
                    set -e
                    tar -xf - -C /app
                    npm ci --no-audit --no-fund
                    CI= npm run build
                '
            """.trimIndent()
        }
        script {
            name = "Frontend: push"
            id = "Frontend_push"
            scriptContent = """
                CHECKOUT="%teamcity.build.checkoutDir%"
                REG="%env.DOCKER_REGISTRY%"
                VER="%GitVersion.SemVer%"
                
                TMPCTX="${'$'}(mktemp -d)"
                # Detecta carpeta de artefactos (adjust si usas .next/out)
                ART="build"; [ -d "${'$'}CHECKOUT/frontend/${'$'}ART" ] || ART="dist"
                cp -R "${'$'}CHECKOUT/frontend/${'$'}ART" "${'$'}TMPCTX/${'$'}ART"
                
                cat > "${'$'}TMPCTX/Dockerfile" <<'EOF'
                FROM nginx:alpine
                ARG ART=build
                COPY ${'$'}{ART}/ /usr/share/nginx/html/
                RUN printf 'server {\n  listen 80;\n  server_name _;\n  root /usr/share/nginx/html;\n  location / { try_files ${'$'}${'$'}uri /index.html; }\n}\n' > /etc/nginx/conf.d/default.conf
                EOF
                
                docker build -t "${'$'}REG/tunefy/frontend:${'$'}VER" --build-arg ART="${'$'}ART" "${'$'}TMPCTX"
                docker push "${'$'}REG/tunefy/frontend:${'$'}VER"
                echo "##teamcity[buildStatus text='Pushed frontend:${'$'}VER']"
            """.trimIndent()
        }
    }

    triggers {
        vcs {
            triggerRules = "+:*"
            branchFilter = ""
            perCheckinTriggering = true
            enableQueueOptimization = false
        }
    }
})

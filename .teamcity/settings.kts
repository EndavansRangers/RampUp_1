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
        param("GitVersion.SemVer", "1.0.0")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "GitVersion"
            id = "GitVersion"
            scriptContent = """ls -la "%teamcity.build.checkoutDir%/.git" || (echo "No hay .git"; exit 2)"""
        }
        script {
            name = "borrar"
            id = "borrar"
            scriptContent = """
                #!/bin/sh   
                #usamos POSIX
                set -eu
                
                CHECKOUT="%teamcity.build.checkoutDir%"
                echo ">> Checkout: ${'$'}CHECKOUT"
                
                # Sanity: revisamos que se tenga un .git
                if [ ! -d "${'$'}CHECKOUT/.git" ]; then
                  echo "FALTA .git en ${'$'}CHECKOUT"
                  ls -la "${'$'}CHECKOUT"
                  exit 1
                fi
                
                TMPROOT="${'$'}(mktemp -d)"
                CLONE="${'$'}TMPROOT/repo"
                
                echo ">> Clonando repo limpio (sin hardlinks/alternates) a: ${'$'}CLONE" #se usa para que GitVersion vea metadata 
                git clone --no-local --no-hardlinks "${'$'}CHECKOUT" "${'$'}CLONE"
                #borarr cache
                rm -rf "${'$'}CLONE/.git/gitversion_cache" || true
                
                # Determinar rama del build (normaliza refs/heads/*) 
                BR_RAW="${'$'}{TEAMCITY_BUILD_BRANCH:-%teamcity.build.branch%}"
                BR="${'$'}(echo "${'$'}BR_RAW" | sed 's#^refs/heads/##')"
                if [ -n "${'$'}BR" ] && git -C "${'$'}CLONE" show-ref --verify --quiet "refs/heads/${'$'}BR"; then
                  echo ">> Checkout a rama: ${'$'}BR"
                  git -C "${'$'}CLONE" checkout "${'$'}BR"
                else
                  echo ">> Sigo con HEAD actual"
                fi
                
                echo ">> Host .git sanity:"
                git -C "${'$'}CLONE" rev-parse --is-inside-work-tree || true
                git -C "${'$'}CLONE" show -s --format='%h %s' || true
                
                echo ">> Calculando SemVer vía tar-stream + dotnet SDK + GitVersion.Tool"
                calc_var () {
                  VAR="${'$'}1"
                  tar -C "${'$'}CLONE" -cf - . \
                  | docker run --rm -i mcr.microsoft.com/dotnet/sdk:8.0-alpine sh -lc "
                      set -e
                      apk add --no-cache git >/dev/null
                      mkdir -p /repo
                      tar -xf - -C /repo
                      git config --global --add safe.directory /repo
                      rm -rf /repo/.git/gitversion_cache || true
                      dotnet tool install -g GitVersion.Tool --version 5.12.0 >/dev/null
                      ~/.dotnet/tools/dotnet-gitversion /repo /showvariable ${'$'}VAR
                    "
                }
                
                SEMVER="${'$'}(calc_var SemVer)"
                FULL="${'$'}(calc_var FullSemVer)"
                
                [ -n "${'$'}SEMVER" ] || { echo 'GitVersion no devolvió SemVer'; exit 1; }
                
                echo ">> SemVer=${'$'}SEMVER"
                echo ">> FullSemVer=${'$'}FULL"
                
                # Publicar para los siguientes steps
                echo "##teamcity[buildNumber '${'$'}SEMVER']"
                echo "##teamcity[setParameter name='env.BUILD_VERSION' value='${'$'}SEMVER']"
                echo "##teamcity[setParameter name='env.DOCKER_TAG' value='${'$'}SEMVER']"
                echo "##teamcity[setParameter name='system.GitVersion.SemVer' value='${'$'}SEMVER']"
                
                rm -rf "${'$'}TMPROOT"
                echo ">> OK version step"
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
})

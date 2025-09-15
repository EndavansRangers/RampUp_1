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
        param("env.DOCKER_TAG", "1")
        param("GitVersion.SemVer", "1.1.0")
    }

    vcs {
        root(DslContext.settingsRoot)
    }

    steps {
        script {
            name = "GitVersion"
            id = "borrar"
            scriptContent = """
                set -eu pipefail
                
                CHECKOUT="%teamcity.build.checkoutDir%"
                [ -d "${'$'}CHECKOUT/.git" ] || { echo "Falta .git en ${'$'}CHECKOUT"; ls -la "${'$'}CHECKOUT"; exit 2; }
                
                TMP="${'$'}(mktemp -d)"
                BUNDLE="${'$'}TMP/repo.bundle"
                CLONE="${'$'}TMP/repo"
                OUT="${'$'}TMP/out.txt"
                ERR="${'$'}TMP/err.txt"
                
                echo ">> Creando bundle autocontenido del checkout"
                git -C "${'$'}CHECKOUT" bundle create "${'$'}BUNDLE" --all --tags
                
                echo ">> Clonando desde el bundle (sin alternates)"
                git clone "${'$'}BUNDLE" "${'$'}CLONE"
                
                # Cambia a la rama del build si TeamCity la expone; si no, deja HEAD
                BR="${'$'}{TEAMCITY_BUILD_BRANCH:-}"; BR="${'$'}{BR#refs/heads/}"
                if [[ -n "${'$'}BR" ]]; then
                  echo ">> Checkout a rama: ${'$'}BR"
                  git -C "${'$'}CLONE" checkout "${'$'}BR" || true
                fi
                
                echo ">> Calculando SemVer con GitVersion (en contenedor)"
                # Usamos dotnet SDK (tiene tar y paquete git disponible) y evitamos bind-mounts
                if ! tar -C "${'$'}CLONE" -cf - . \
                  | docker run --rm -i mcr.microsoft.com/dotnet/sdk:8.0-alpine sh -lc '
                      set -e
                      apk add --no-cache git >/dev/null
                      mkdir -p /repo
                      tar -xf - -C /repo
                      git config --global --add safe.directory /repo
                      dotnet tool install -g GitVersion.Tool --version 5.12.0 >/dev/null
                      ~/.dotnet/tools/dotnet-gitversion /repo /showvariable SemVer
                    ' >"${'$'}OUT" 2>"${'$'}ERR"
                then
                  echo "---- GitVersion STDERR ----"; cat "${'$'}ERR" || true
                  echo "---- GitVersion STDOUT ----"; cat "${'$'}OUT" || true
                  rm -rf "${'$'}TMP"
                  exit 1
                fi
                
                SEMVER="${'$'}(tr -d '\r' < "${'$'}OUT" | tail -n1)"
                [ -n "${'$'}SEMVER" ] || { echo "SemVer vacío"; echo "STDOUT:"; cat "${'$'}OUT"; echo "STDERR:"; cat "${'$'}ERR"; rm -rf "${'$'}TMP"; exit 1; }
                
                echo "GitVersion.SemVer calculado: ${'$'}SEMVER"
                
                # Publicar variables para los siguientes steps (sin usar %GitVersion.SemVer%)
                echo "##teamcity[setParameter name='env.DOCKER_TAG' value='${'$'}SEMVER']"
                echo "##teamcity[buildNumber '${'$'}SEMVER']"
                
                rm -rf "${'$'}TMP"
                echo ">> OK GitVersion"
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
                set -eu
                
                CHECKOUT="%teamcity.build.checkoutDir%"
                REG="%env.DOCKER_REGISTRY%"
                VER="%env.DOCKER_TAG%"
                
                echo "Usando tag: ${'$'}VER"
                
                # Construir desde la carpeta backend (evita contexto vacío)
                docker build -t "${'$'}REG/tunefy/backend:${'$'}VER" -f "${'$'}CHECKOUT/backend/Dockerfile" "${'$'}CHECKOUT/backend"
                docker push "${'$'}REG/tunefy/backend:${'$'}VER"
                echo "Pushed backend:${'$'}VER"
            """.trimIndent()
        }
        script {
            name = "Frontend: build"
            id = "Frontend_build"
            scriptContent = """
                set -eu
                CHECKOUT="%teamcity.build.checkoutDir%"
                FE="${'$'}CHECKOUT/frontend"
                
                # Enviamos el contenido del frontend al contenedor por stdin
                # y devolvemos SOLO la carpeta /app/build por stdout.
                tar -C "${'$'}FE" -cf - . \
                | docker run --rm -i -w /app node:18-alpine sh -lc '
                  set -e
                  # Nada de stdout antes del tar final:
                  # - Instalamos tar si hace falta (silenciado)
                  apk add --no-cache tar >/dev/null 2>&1 || true
                  # - Extraemos el código (logs a stderr)
                  tar -xf - -C /app 1>&2
                  # - Dependencias y build (logs a stderr)
                  npm ci --no-audit --no-fund 1>&2
                  CI= npm run build 1>&2
                  # - Validamos que exista /app/build
                  [ -d /app/build ] || { echo "No se generó /app/build" >&2; exit 3; }
                  # - ÚNICO stdout válido: el tar de /app/build
                  exec tar -C /app -cf - build
                ' | tar -C "${'$'}FE" -xvf -
                
                # Verificación local
                ls -la "${'$'}FE/build"
            """.trimIndent()
        }
        script {
            name = "Frontend: push"
            id = "Frontend_push"
            scriptContent = """
                set -eu
                
                CHECKOUT="%teamcity.build.checkoutDir%"
                REG="%env.DOCKER_REGISTRY%"
                VER="%env.DOCKER_TAG%"
                FE="${'$'}CHECKOUT/frontend"
                
                # Detectar artefactos (CRA=build, Vite=dist, Next=out)
                ART=""
                for d in build dist out; do
                  if [ -d "${'$'}FE/${'$'}d" ]; then ART="${'$'}d"; break; fi
                done
                if [ -z "${'$'}ART" ]; then
                  echo "No se encontraron artefactos (build/dist/out) en ${'$'}FE"
                  ls -la "${'$'}FE"
                  exit 2
                fi
                echo "Artefactos detectados: ${'$'}ART"
                
                # Contexto mínimo
                CTX="${'$'}(mktemp -d)"
                cp -R "${'$'}FE/${'$'}ART" "${'$'}CTX/${'$'}ART"
                
                cat > "${'$'}CTX/Dockerfile" <<'EOF'
                FROM nginx:alpine
                ARG ART=build
                COPY ${'$'}{ART}/ /usr/share/nginx/html/
                RUN printf 'server {\n  listen 80;\n  server_name _;\n  root /usr/share/nginx/html;\n  location / { try_files ${'$'}${'$'}uri /index.html; }\n}\n' > /etc/nginx/conf.d/default.conf
                EOF
                
                docker build -t "${'$'}REG/tunefy/frontend:${'$'}VER" --build-arg ART="${'$'}ART" "${'$'}CTX"
                docker push "${'$'}REG/tunefy/frontend:${'$'}VER"
                echo "Frontend publicado como ${'$'}REG/tunefy/frontend:${'$'}VER"
            """.trimIndent()
        }
        script {
            name = "Create & Deploy Release"
            id = "Create_Deploy_Release"
            scriptContent = """
                set -eu pipefail
                OCTO_URL="http://10.20.0.221:8080"
                OCTO_API_KEY="API-ZLBBY7WFTKNWCWQFQZ27HPZFATYHOJU9"
                SPACE="Default"
                PROJECT="Tunefy"
                ENV="Dev"
                REG="%env.DOCKER_REGISTRY%"
                REL="%env.DOCKER_TAG%"
                
                # 1) Crear release con el mismo número de GitVersion
                docker run --rm octopusdeploy/octo:9.1.7 \
                  create-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                  --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" \
                  --ignoreExisting
                
                # 2) Desplegarla a Dev y esperar resultado
                docker run --rm octopusdeploy/octo:9.1.7 \
                  deploy-release --server "${'$'}OCTO_URL" --apiKey "${'$'}OCTO_API_KEY" \
                  --space "${'$'}SPACE" --project "${'$'}PROJECT" --releaseNumber "${'$'}REL" \
                  --deployTo "${'$'}ENV" --progress --waitForDeployment \
                    --variable "BACKEND_IMAGE=${'$'}{REG}/tunefy/backend:${'$'}{REL}" \
                  --variable "FRONTEND_IMAGE=${'$'}{REG}/tunefy/frontend:${'$'}{REL}"
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

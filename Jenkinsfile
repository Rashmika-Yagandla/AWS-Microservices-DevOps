
stage('Validate and Test') {
    steps {
        powershell '''
            $ErrorActionPreference = "Stop"

            $pythonExe = "C:\\Users\\yagan\\AppData\\Local\\Python\\pythoncore-3.14-64\\python.exe"

            if (!(Test-Path $pythonExe)) {
                throw "Python executable not found: $pythonExe"
            }

            foreach ($svc in @("user-service", "product-service", "order-service")) {
                Write-Host "Testing $svc"

                $venv = Join-Path $PWD ".venv-$svc"

                & $pythonExe -m venv $venv
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                $python = Join-Path $venv "Scripts\\python.exe"

                & $python -m pip install -q -r "services/$svc/requirements.txt" pytest
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                Push-Location "services/$svc"
                try {
                    & $python -m pytest -q
                    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                }
                finally {
                    Pop-Location
                }
            }

            docker compose config -q
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        '''
    }
}

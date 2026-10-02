@echo off
title QueueLess Master Controller
echo ========================================================
echo     1. Starting XAMPP (MySQL Database & Apache)...
echo ========================================================
:: Start XAMPP MySQL and Apache
start "" "D:\xampp\xampp_start.exe"
start "" "D:\xampp\xampp-control.exe"

@echo off
echo ========================================================
echo        Starting All QueueLess Microservices...
echo ========================================================

:: 1. API Gateway (Port 8081)
start "API Gateway (8081)" cmd /k "cd /d "D:\queueless project\queueless\backend\api-gateway" && .\mvnw.cmd spring-boot:run"

:: 2. Auth Service (Port 8082)
start "Auth Service (8082)" cmd /k "cd /d "D:\queueless project\queueless\backend\auth-service" && .\mvnw.cmd spring-boot:run"

:: 3. Office Service (Port 8083)
start "Office Service (8083)" cmd /k "cd /d "D:\queueless project\queueless\backend\office-service" && .\mvnw.cmd spring-boot:run"

:: 4. Customer Service (Port 8084)
start "Customer Service (8084)" cmd /k "cd /d "D:\queueless project\queueless\backend\customer-service" && .\mvnw.cmd spring-boot:run"

echo All 4 services have been launched in separate windows!
pause
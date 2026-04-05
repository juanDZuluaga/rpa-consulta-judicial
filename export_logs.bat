@echo off
echo Exportando logs...

docker exec -i postgres psql -U n8n -d logs_db -c "SELECT * FROM logs;" > logs\logs.txt

echo Logs exportados en carpeta logs
pause
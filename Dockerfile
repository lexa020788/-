# Используем стабильную версию Python
FROM python:3.10-slim

# Задаем рабочую папку в контейнере
WORKDIR /app

# Сначала копируем зависимости и ставим их
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копируем остальной код
COPY . .

# Открываем порт для Koyeb
EXPOSE 8000

# Запускаем наше веб-приложение через сервер Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]

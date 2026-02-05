# syntax=docker/dockerfile:1

FROM python:3.13-slim

# Безопасность
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Рабочая директория
WORKDIR /app

# зависимости для кэширования слоёв
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# код приложения
COPY . .

# Создаём не-root пользователя
RUN useradd -m -r appuser && chown -R appuser:appuser /app
USER appuser

# Порт
EXPOSE 6000

# Запус
CMD ["python", "app.py"]
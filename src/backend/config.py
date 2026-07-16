import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '11.0.27')
    CODENAME = os.environ.get('CODENAME', 'Smart Optimizer')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2026-07-16')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    OLLAMA_HOST = 'http://host.docker.internal:11434'
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:14b')
    RECOMMENDED_MODEL = os.environ.get('RECOMMENDED_MODEL', 'deepseek-r1:14b')
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 5))
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    ENABLE_AUTO_OPTIMIZE = os.environ.get('ENABLE_AUTO_OPTIMIZE', 'i').lower() == 'i'
    ENABLE_RESOURCE_MONITOR = os.environ.get('ENABLE_RESOURCE_MONITOR', 'i').lower() == 'i'
    ENABLE_SMART_SWITCH = os.environ.get('ENABLE_SMART_SWITCH', 'i').lower() == 'i'
    ENABLE_AI_ASSISTANT = os.environ.get('ENABLE_AI_ASSISTANT', 'i').lower() == 'i'
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    OPTIMAL_MEMORY_LIMIT = os.environ.get('OPTIMAL_MEMORY_LIMIT', '24G')
    OPTIMAL_REDIS = os.environ.get('OPTIMAL_REDIS', '512mb')
    OPTIMAL_PG_BUFFERS = os.environ.get('OPTIMAL_PG_BUFFERS', '512MB')
"""Automatikus Modell Optimalizáló"""
import os, json, requests, subprocess, psutil
from datetime import datetime
from models import db, SystemSettings, OptimizationLog

class ModelOptimizer:
    MODEL_CONFIGS = {
        'deepseek-r1:1.5b': {'max_workers': 4, 'batch_size': 8, 'memory_limit': '4G', 'num_parallel': 4, 'max_loaded_models': 2, 'redis_maxmemory': '128mb', 'pg_buffers': '128MB', 'description': 'Teszteléshez'},
        'deepseek-r1:7b': {'max_workers': 3, 'batch_size': 6, 'memory_limit': '12G', 'num_parallel': 3, 'max_loaded_models': 2, 'redis_maxmemory': '256mb', 'pg_buffers': '256MB', 'description': '16GB RAM-hoz'},
        'deepseek-r1:8b': {'max_workers': 3, 'batch_size': 5, 'memory_limit': '16G', 'num_parallel': 2, 'max_loaded_models': 1, 'redis_maxmemory': '512mb', 'pg_buffers': '512MB', 'description': 'Általános használatra'},
        'deepseek-r1:14b': {'max_workers': 3, 'batch_size': 5, 'memory_limit': '24G', 'num_parallel': 2, 'max_loaded_models': 1, 'redis_maxmemory': '512mb', 'pg_buffers': '512MB', 'description': 'Jobb minőség'},
        'deepseek-r1:32b': {'max_workers': 1, 'batch_size': 2, 'memory_limit': '30G', 'num_parallel': 1, 'max_loaded_models': 1, 'redis_maxmemory': '256mb', 'pg_buffers': '256MB', 'description': 'Max minőség'},
        'deepseek-r1:70b': {'max_workers': 1, 'batch_size': 1, 'memory_limit': '60G', 'num_parallel': 1, 'max_loaded_models': 1, 'redis_maxmemory': '128mb', 'pg_buffers': '128MB', 'description': 'Professzionális'}
    }
    
    def __init__(self, app=None):
        self.app = app
        self.ollama_host = app.config.get('OLLAMA_HOST', 'http://localhost:11434') if app else 'http://localhost:11434'
    
    def optimize_for_model(self, model_name):
        config = self.MODEL_CONFIGS.get(model_name)
        if not config:
            return {'success': False, 'error': f'Ismeretlen modell: {model_name}'}
        
        results = {'model': model_name, 'config': config, 'steps': []}
        
        if self.app:
            self.app.config['MAX_WORKERS'] = config['max_workers']
            self.app.config['BATCH_SIZE'] = config['batch_size']
        results['steps'].append({'step': 'env', 'success': True})
        
        try:
            import redis
            r = redis.Redis(host='redis', port=6379, decode_responses=True)
            r.config_set('maxmemory', config['redis_maxmemory'])
            results['steps'].append({'step': 'redis', 'success': True})
        except:
            results['steps'].append({'step': 'redis', 'success': False})
        
        try:
            log = OptimizationLog(model=model_name, action='optimize', details=json.dumps(config), created_at=datetime.utcnow())
            db.session.add(log); db.session.commit()
        except:
            pass
        
        return results
    
    def get_recommended_model(self):
        total_ram = psutil.virtual_memory().total / (1024**3)
        free_ram = psutil.virtual_memory().available / (1024**3)
        if total_ram >= 64 and free_ram > 50: return 'deepseek-r1:32b'
        elif total_ram >= 32 and free_ram > 20: return 'deepseek-r1:14b'
        elif total_ram >= 16 and free_ram > 10: return 'deepseek-r1:8b'
        elif total_ram >= 8: return 'deepseek-r1:7b'
        return 'deepseek-r1:1.5b'
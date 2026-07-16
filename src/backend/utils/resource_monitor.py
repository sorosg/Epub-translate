"""Valós Idejű Erőforrás Figyelő"""
import psutil
import time
from datetime import datetime

class ResourceMonitor:
    def __init__(self):
        self.history = []
    
    def get_current_stats(self):
        return {
            'timestamp': datetime.ucnow().isoformat(),
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
            'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
            'disk_percent': psutil.disk_usage('/').percent,
            'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2),
        }

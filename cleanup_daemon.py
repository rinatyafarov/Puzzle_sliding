#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Фоновый процесс для автоматической очистки устаревших игровых сессий.
Запускать отдельно от основного Flask приложения.
"""

import time
import sys
import os
import logging
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('cleanup_daemon.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('cleanup_daemon')

# Импортируем конфигурацию
try:
    from config import SESSION_TIMEOUT_MINUTES
except ImportError:
    SESSION_TIMEOUT_MINUTES = 30
    logger.warning(f"Could not import config, using default timeout: {SESSION_TIMEOUT_MINUTES} minutes")

# Импортируем функцию очистки из app.py
try:
    from app import cleanup_stale_sessions
except ImportError as e:
    logger.error(f"Failed to import from app.py: {e}")
    sys.exit(1)


def run_cleanup_daemon(check_interval_minutes=5, timeout_minutes=None):
    """
    Запускает демона очистки, который проверяет устаревшие сессии
    каждые check_interval_minutes минут и завершает сессии,
    неактивные более timeout_minutes минут.

    Args:
        check_interval_minutes: интервал проверки в минутах
        timeout_minutes: таймаут неактивности в минутах (из config по умолчанию)
    """
    if timeout_minutes is None:
        timeout_minutes = SESSION_TIMEOUT_MINUTES

    logger.info(
        f"Starting cleanup daemon (check interval: {check_interval_minutes} min, timeout: {timeout_minutes} min)")

    while True:
        try:
            logger.info("Running cleanup check...")
            cleanup_stale_sessions(timeout_minutes)
            logger.info("Cleanup check completed")

            # Ждем до следующей проверки
            time.sleep(check_interval_minutes * 60)

        except KeyboardInterrupt:
            logger.info("Daemon stopped by user")
            break
        except Exception as e:
            logger.error(f"Error in cleanup daemon: {e}")
            # При ошибке ждем минуту и пробуем снова
            time.sleep(60)


def run_one_time_cleanup(timeout_minutes=None):
    """
    Запускает одноразовую очистку (удобно для cron)

    Args:
        timeout_minutes: таймаут неактивности в минутах (из config по умолчанию)
    """
    if timeout_minutes is None:
        timeout_minutes = SESSION_TIMEOUT_MINUTES

    logger.info(f"Running one-time cleanup (timeout: {timeout_minutes} min)")
    try:
        cleanup_stale_sessions(timeout_minutes)
        logger.info("One-time cleanup completed")
    except Exception as e:
        logger.error(f"Error in one-time cleanup: {e}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='Cleanup daemon for sliding puzzle game sessions')
    parser.add_argument('--daemon', action='store_true', help='Run as daemon (continuous mode)')
    parser.add_argument('--interval', type=int, default=5, help='Check interval in minutes (default: 5)')
    parser.add_argument('--timeout', type=int, default=SESSION_TIMEOUT_MINUTES,
                        help=f'Session timeout in minutes (default: {SESSION_TIMEOUT_MINUTES})')
    parser.add_argument('--one-time', action='store_true', help='Run one-time cleanup and exit')

    args = parser.parse_args()

    if args.one_time:
        run_one_time_cleanup(args.timeout)
    elif args.daemon:
        run_cleanup_daemon(args.interval, args.timeout)
    else:
        # По умолчанию запускаем один раз
        run_one_time_cleanup(args.timeout)
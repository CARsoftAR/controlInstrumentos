#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys

if sys.stdout is None:
    sys.stdout = open(os.devnull, 'w')
if sys.stderr is None:
    sys.stderr = open(os.devnull, 'w')


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    if len(sys.argv) == 1:
        sys.argv.extend(['runserver', '8000', '--noreload'])
        
    try:
        import django
        from django.core.management import call_command
        django.setup()
        print("Verificando/Aplicando migraciones de base de datos...")
        call_command('migrate', interactive=False)
        
        # También asegurar que existe un superusuario por defecto si está vacía
        from django.contrib.auth import get_user_model
        User = get_user_model()
        if not User.objects.filter(username='admin').exists():
            print("Creando usuario admin por defecto...")
            User.objects.create_superuser('admin', 'admin@abbamat.com', 'admin')
            
    except Exception as e:
        print(f"Error automigrating: {e}")
    
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()

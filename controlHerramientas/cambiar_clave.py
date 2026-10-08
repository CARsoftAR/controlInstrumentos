import os
import django

# Configurar el entorno de Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'controlHerramientas.settings')
django.setup()

from django.contrib.auth.models import User

# Cambiar la contraseña del usuario 'admin' (o el que necesites)
try:
    user = User.objects.get(username='admin')
    user.set_password('123456')  # Aquí defines la nueva contraseña en texto plano
    user.save()
    print("¡Contraseña actualizada exitosamente para el usuario 'admin' con la clave: 123456!")
except User.DoesNotExist:
    print("El usuario no existe.")
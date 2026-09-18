from django.contrib.auth import authenticate
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json

@csrf_exempt
def login_usuario(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            username = data.get('username')
            password = data.get('password')
            
            print(f"INTENTO DE LOGIN -> Usuario: '{username}', Pass: '{password}'")
            
            user = authenticate(username=username, password=password)
            
            if user is not None:
                return JsonResponse({
                    'success': True,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'is_staff': user.is_staff
                    }
                }, status=200)
            else:
                return JsonResponse({
                    'success': False,
                    'message': 'Usuario o contraseña incorrectos'
                }, status=400)
        except Exception as e:
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
            
    return JsonResponse({'success': False, 'message': 'Método no permitido'}, status=405)


def listar_instrumentos(request):
    # Traemos todos los instrumentos de la base de datos
    instrumentos = Instrumento.objects.all().values()
    # Convertimos la lista de objetos a una lista de diccionarios
    data = list(instrumentos)
    # Devolvemos el JSON para que Flutter lo lea
    return JsonResponse(data, safe=False)

from django.contrib.auth.models import User
from rest_framework.decorators import api_view

@api_view(['GET'])
def listar_usuarios(request):
    try:
        users = User.objects.all().order_by('id')
        data = [{'id': u.id, 'username': u.username, 'is_staff': u.is_staff} for u in users]
        return JsonResponse({'success': True, 'usuarios': data})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@api_view(['POST'])
def crear_usuario(request):
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')
        is_staff = data.get('is_staff', False)
        
        if not username or not password:
            return JsonResponse({'success': False, 'message': 'Faltan campos obligatorios'}, status=400)
            
        if User.objects.filter(username=username).exists():
            return JsonResponse({'success': False, 'message': 'El nombre de usuario ya existe'}, status=400)
            
        user = User.objects.create_user(username=username, password=password)
        user.is_staff = is_staff
        user.save()
        return JsonResponse({'success': True})
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@api_view(['POST'])
def editar_usuario(request, id):
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')
        is_staff = data.get('is_staff')
        
        user = User.objects.get(id=id)
        
        if username:
            if User.objects.filter(username=username).exclude(id=id).exists():
                return JsonResponse({'success': False, 'message': 'El nombre de usuario ya existe'}, status=400)
            user.username = username
            
        if password and password.strip() != "":
            user.set_password(password)
            
        if is_staff is not None:
            user.is_staff = is_staff
            
        user.save()
        return JsonResponse({'success': True})
    except User.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Usuario no encontrado'}, status=404)
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)

@api_view(['DELETE'])
def eliminar_usuario(request, id):
    try:
        user = User.objects.get(id=id)
        user.delete()
        return JsonResponse({'success': True})
    except User.DoesNotExist:
        return JsonResponse({'success': False, 'message': 'Usuario no encontrado'}, status=404)
    except Exception as e:
        return JsonResponse({'success': False, 'message': str(e)}, status=500)
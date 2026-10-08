from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse

def api_root_view(request):
    return JsonResponse({
        "status": "online",
        "message": "Servidor ABBAMAT API activo y funcionando correctamente.",
        "endpoints": {
            "admin": "/admin/",
            "api": "/api/"
        }
    })

urlpatterns = [
    path('', api_root_view, name='api-root'),
    path('admin/', admin.site.urls),
    path('api/', include('metrologia.urls')), # Apuntando directo a tu app real
]

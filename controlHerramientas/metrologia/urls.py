from django.urls import path 
from . import views 
from . import views_auth

urlpatterns = [ 
    path('auth/login/', views_auth.login_usuario, name='api-login'), 
    path('debug-db/', views.debug_db_path, name='debug_db_path'),
    path('dashboard/stats/', views.dashboard_stats, name='dashboard_stats'),
    path('config/', views.configuracion_view, name='configuracion_view'),
    path('instrumentos/', views.listar_instrumentos, name='listar_instrumentos'), 
    path('operarios/', views.listar_operarios, name='listar_operarios'),
    path('prestamos/', views.listar_prestamos, name='listar_prestamos'),
    path('prestamos/crear/', views.crear_prestamo, name='crear_prestamo'),
    path('prestamos/eliminar/<int:id>/', views.eliminar_prestamo, name='eliminar_prestamo'),
    path('prestamos/devolver/<int:id>/', views.devolver_prestamo, name='devolver_prestamo'),
    path('instrumentos/crear/', views.crear_instrumento, name='crear_instrumento'),
    path('instrumentos/editar/<str:codigo>/', views.editar_instrumento, name='editar_instrumento'),
    path('instrumentos/eliminar/<str:codigo>/', views.eliminar_instrumento, name='eliminar_instrumento'),
    
    path('operarios/crear/', views.crear_operario, name='crear_operario'),
    path('operarios/editar/<str:legajo>/', views.editar_operario, name='editar_operario'),
    path('operarios/eliminar/<str:legajo>/', views.eliminar_operario, name='eliminar_operario'),
    
    path('sistema/backup/', views.crear_backup, name='crear_backup'),
    path('sistema/backups/', views.listar_backups, name='listar_backups'),
    path('sistema/backup/eliminar/', views.eliminar_backup, name='eliminar_backup'),
    path('sistema/backup/restaurar/', views.restaurar_backup, name='restaurar_backup'),
    path('sistema/exportar/instrumentos/', views.exportar_instrumentos_xlsx, name='exportar_instrumentos_xlsx'),
    path('sistema/exportar/prestamos/', views.exportar_prestamos_xlsx, name='exportar_prestamos_xlsx'),
    path('usuarios/', views_auth.listar_usuarios, name='listar_usuarios'),
    path('usuarios/crear/', views_auth.crear_usuario, name='crear_usuario'),
    path('usuarios/editar/<int:id>/', views_auth.editar_usuario, name='editar_usuario'),
    path('usuarios/eliminar/<int:id>/', views_auth.eliminar_usuario, name='eliminar_usuario'),
    path('instrumentos/historial-calibracion/<str:codigo>/', views.listar_historial_calibracion, name='listar_historial_calibracion'),
    path('instrumentos/historial-calibracion/<str:codigo>/crear/', views.crear_historial_calibracion, name='crear_historial_calibracion'),
]

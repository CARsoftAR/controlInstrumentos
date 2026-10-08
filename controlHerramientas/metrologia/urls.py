from django.urls import path, include 
from rest_framework.routers import DefaultRouter
from . import views 
from . import views_auth

router = DefaultRouter()
router.register(r'ubicaciones_api', views.UbicacionViewSet, basename='ubicacion')

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
    
    path('', include(router.urls)),
    
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
    path('instrumentos/auditoria/<str:codigo>/', views.listar_auditoria, name='listar_auditoria'),
    path('auditoria/', views.listar_auditoria_global, name='listar_auditoria_global'),
    
    # PDFs
    path('reportes/pdf/ficha/<str:codigo>/', __import__('metrologia.pdf_views').pdf_views.generar_pdf_ficha_instrumento, name='pdf_ficha'),
    path('reportes/pdf/vencidos/', __import__('metrologia.pdf_views').pdf_views.generar_pdf_reporte_vencidos, name='pdf_vencidos'),
    path('reportes/pdf/inventario/', __import__('metrologia.pdf_views').pdf_views.generar_pdf_inventario, name='pdf_inventario'),
    
    # Gestor de Base de Datos
    path('database/tables/', __import__('metrologia.database_views').database_views.list_tables, name='db_list_tables'),
    path('database/tables/<str:table_name>/', __import__('metrologia.database_views').database_views.explore_table, name='db_explore_table'),
    path('database/tables/<str:table_name>/schema/', __import__('metrologia.database_views').database_views.table_schema, name='db_table_schema'),
    path('database/execute/', __import__('metrologia.database_views').database_views.execute_sql, name='db_execute_sql'),
    path('database/maintenance/', __import__('metrologia.database_views').database_views.database_maintenance, name='db_maintenance'),
    path('database/clear-system-tables/', __import__('metrologia.database_views').database_views.clear_system_tables, name='db_clear_system_tables'),
    path('database/import-instruments/', __import__('metrologia.database_views').database_views.import_instruments, name='db_import_instruments'),
    path('database/instrument-template/', __import__('metrologia.database_views').database_views.instrument_template, name='db_instrument_template'),
]

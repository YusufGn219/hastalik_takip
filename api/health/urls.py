from api.health.views import DailyLogListCreateView, DailyLogDetailView
from django.urls import path

urlpatterns = [
    path('logs/', DailyLogListCreateView.as_view(), name='daily-log-list-create'),
    path('logs/<int:pk>/', DailyLogDetailView.as_view(), name='daily-log-detail'),
]
from api.health.views import (
    DailyLogListCreateView, 
    DailyLogDetailView, 
    SymptomListView, 
    SymptomDetailView, 
    SymptomEntryListCreateView, 
    SymptomEntryDetailView, 
    TimelineView)
from django.urls import path

urlpatterns = [
    path('logs/', DailyLogListCreateView.as_view(), name='daily-log-list-create'),
    path('logs/<int:pk>/', DailyLogDetailView.as_view(), name='daily-log-detail'),
    path('symptoms/', SymptomListView.as_view(), name='symptom-list'),
    path('symptoms/<int:pk>/', SymptomDetailView.as_view(), name='symptom-detail'),
    path('symptom-entries/', SymptomEntryListCreateView.as_view(), name='symptom-entry-list'),
    path('symptom-entries/<int:pk>/', SymptomEntryDetailView.as_view(), name='symptom-entry-detail'),
    path('timeline/', TimelineView.as_view(), name='timeline'),
]
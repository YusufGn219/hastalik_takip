# 🏥 Health Tracking Application

A mobile application for tracking, analyzing and visualizing 
personal health data. Built with Flutter (mobile) + Django REST Framework (backend).

## 📌 Overview

A personal health assistant combining sleep, water intake, mood, 
energy, symptoms, medication and episode tracking in a single platform.

## ✅ Features

- 👤 User system — JWT authentication, email login, profile photo
- 📅 Daily log — sleep, water, mood (1-5), energy (1-5)
- 🤒 Symptom tracking — time-based entries, severity (1-10), location
- ⚡ Episode management — start, add entries, close, duration tracking
- 💊 Medication tracking — general, chronic and recurring medication scenarios
- 🔔 Recurring medication reminders — weekly notifications, Istanbul timezone
- 📊 Analytics — symptom frequency/trends, medication effect, routine adherence (7/30/90 days)
- 🕐 Unified timeline — all health data in a single screen
- 🎨 Material 3 theme — automatic Light/Dark switching

## 🛠️ Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Django](https://img.shields.io/badge/Django-092E20?style=flat&logo=django&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)

## 📁 Architecture

Layered architecture: `api/ → services/ → apps/ → DB`

| Layer | Description |
|-------|-------------|
| `api/` | Serializers, views, URL definitions |
| `services/` | Timeline, episode, medication, analytics business logic |
| `apps/` | Database models (users, health) |
| `mobile/lib/` | Flutter features, core, theme |

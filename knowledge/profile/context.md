---
type: 'User Workspace Profile'
title: 'Perfil y Contexto del Espacio de Trabajo'
description: 'Define quién utiliza este espacio, el propósito de sus documentos y sus preferencias de comunicación.'
status: 'template'
tags: ['profile', 'onboarding', 'preferences']
timestamp: '2026-10-22T22:45:00-06:00'
---

# Perfil y Contexto del Espacio de Trabajo

> **Estado actual:** Plantilla inicial (`status: template`). Cuando se realice la bienvenida con el usuario mediante la skill `onboarding`, cambia `status: 'configured'` en el encabezado YAML y completa las secciones inferiores.

## 1. Propósito Principal
- **Área o proyecto:** *(Pendiente de definir con el usuario: ej. escritura, consultoría, gestión administrativa, investigación personal)*
- **Objetivo principal:** *(Qué busca lograr el usuario en este espacio)*

## 2. Preferencias de Trabajo y Estilo
- **Idioma preferido:** Español
- **Tono de redacción en documentos:** Claro, directo y profesional *(ajustar según preferencia del usuario)*
- **Frecuencia de puntos de guardado:** Automático antes de cambios grandes y al cerrar cada bloque importante de trabajo.

## 3. Convenciones del Proyecto
- Los archivos entrantes sin clasificar se depositan en `workspace/bandeja/`.
- La arquitectura general del asistente está documentada en [Arquitectura del Agente](../system/agent-architecture.md).

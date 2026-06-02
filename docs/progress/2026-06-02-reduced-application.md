\# Progress Note - 2026-06-02



\## Milestone

Reduced Online Boutique application successfully deployed on local Kubernetes.



\## Namespace

\- application



\## Services kept

\- frontend

\- productcatalogservice

\- cartservice

\- redis-cart

\- checkoutservice

\- paymentservice

\- shippingservice

\- currencyservice

\- emailservice



\## Services removed

\- adservice

\- recommendationservice

\- loadgenerator



\## Result

All remaining pods are running successfully. The frontend UI is accessible locally and the reduced application can be used as the base system for thesis experiments.



\## Reason for reduction

The removed services are not required for the selected thesis scenarios: HTTP flood, endpoint scanning, and checkout abuse. The built-in loadgenerator was removed because traffic generation will be controlled separately using custom scripts or Locust.


# Progress Report - 2026-06-02

## Scope

Removed `adservice` and `recommendationservice` from the reduced Online Boutique thesis application and updated project documentation to match the current runtime scope.

## Service Removal Work

- Deleted the `src/adservice` implementation directory, including Java source, Gradle build files, Dockerfile, generated proto support, and service README.
- Deleted the `src/recommendationservice` implementation directory, including Python source, requirements files, Dockerfile, generated proto files, client script, logger, and genproto script.
- Removed frontend startup dependencies on:
  - `AD_SERVICE_ADDR`
  - `RECOMMENDATION_SERVICE_ADDR`
- Removed frontend gRPC connection fields and startup connection calls for ad and recommendation services.
- Removed frontend RPC helper code for:
  - ad retrieval
  - product recommendations
- Removed UI integration for ads and recommendations:
  - deleted `templates/ad.html`
  - deleted `templates/recommendations.html`
  - removed ad blocks from product pages
  - removed recommendation blocks from product, cart, and order pages
  - removed unused ad and recommendation CSS.

## Deployment Configuration Updates

- Updated `application/manifests/application-reduced.yaml` so the frontend no longer receives ad or recommendation service addresses.
- Updated `application/manifests/application-full.yaml` by removing:
  - frontend ad and recommendation environment variables
  - `recommendationservice` Deployment, Service, and ServiceAccount
  - `adservice` Deployment, Service, and ServiceAccount
- Added and adjusted root-level `docker-compose.yml` for the reduced application.
- Fixed Docker Compose build contexts to use repo-root paths such as `./src/frontend` and `./src/checkoutservice`.

## README Update

- Rewrote `README.md` to describe the current reduced thesis scope.
- Documented active services:
  - `frontend`
  - `productcatalogservice`
  - `cartservice`
  - `redis-cart`
  - `checkoutservice`
  - `paymentservice`
  - `shippingservice`
  - `currencyservice`
  - `emailservice`
- Documented removed services:
  - `adservice`
  - `recommendationservice`
  - `loadgenerator`
- Added Docker Compose commands for local application startup.
- Added Kubernetes deployment commands for namespaces and the reduced application manifest.
- Clarified monitoring scope and thesis test scenarios.

## Validation Performed

- `docker compose config`
- `docker compose config --quiet`
- `docker compose build frontend`
- `kubectl apply --dry-run=client -f application/manifests/application-reduced.yaml`
- `kubectl apply --dry-run=client -f application/manifests/application-full.yaml`
- `git diff --check`
- Search checks confirmed no active runtime references remain for `AD_SERVICE_ADDR` or `RECOMMENDATION_SERVICE_ADDR`.

## Result

The reduced application no longer deploys or depends on `adservice` or `recommendationservice`. The README now matches the current project scope and deployment workflow.

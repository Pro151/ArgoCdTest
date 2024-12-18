# Helm chart for Litmus UNS

Litmus UNS is an UNS enabled MQTT broker

[Overview of Litmus UNS](https://litmus.io/litmus-uns/)

## TL;DR

1. Obtain the Kubernetes pull secret from Litmus Automation.
2. Submit the secret to the cluster using the following commands, changing `THE-SECRET_FILENAME` to the actual filename:
   ```console
   kubectl create namespace uns
   kubectl create -f THE-SECRET_FILENAME --namespace=uns
   ```
3. Look up the secret name in the provided file, and use this name instead of `THE-SECRET-NAME` in the next command.
4. Install Litmus UNS:
   ```console
   helm install uns oci://quay.io/litmusautomation/charts/litmus-uns --wait --namespace uns --set "imagePullSecrets[0].name=THE-SECRET-NAME"
   ```

## Introduction

This chart bootstraps a [Litmus-UNS](https://litmus.io/litmus-uns/) deployment on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.8.0+


## Installing the Chart

1. Obtain the Kubernetes pull secret from Litmus Automation
2. Submit the secret to the cluster using this command:
```console
kubectl create namespace uns
kubectl create -f THE-SECRET_FILENAME --namespace=uns
```
3. Look up the secret name in the provided file, and use this name instead of `THE-SECRET-NAME` in the next command.

4. To install the chart with the release name `uns` in namespace `uns`:

```console
helm install uns oci://quay.io/litmusautomation/charts/litmus-uns --wait --namespace uns --set "imagePullSecrets[0].name=THE-SECRET-NAME"
```

The command deploys Litmus UNS on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Deploy with Argo CD

Litmus UNS automatically generates passwords during deployment and stores them in a Kubernetes secret.
This process is managed by the helm upgrade/install command. If a secret already exists, the existing value is used. Otherwise, a random password is generated and stored in the secret.

However, Argo CD generates manifests using the helm template command and applies them to the cluster.
This behavior results in random passwords being generated during every sync.

To deploy the chart with Argo CD, please follow the steps below:

* Pull the chart
```
helm pull oci://quay.io/litmusautomation/charts/litmus-uns --untar
```

* Generate and apply the secret before deployment

It is assumed that the chart will be deployed in the namespace `uns` and the release name will be `uns`.
```
helm template -n uns uns litmus-uns --show-only templates/creds-secret.yaml | kubectl -n uns apply -f -
```

* Disable secret creation during deployment

Deploy the chart with the following parameter:
```
secrets:
  create: false
```

Litmus UNS automatically generates passwords during deployment and stores them in a Kubernetes secret.
This approach is managed by the helm upgrade/install command. If a secret already exists, the existing value is used.
 Otherwise, a random password is generated and stored in the secret.

ArgoCD, however, generates manifests using the helm template command and applies them to the cluster. 
This process results in random passwords being generated on each sync.

In order to deploy the chart with ArgoCD please use the below steps

#### Pull the chart
```
helm pull oci://quay.io/litmusautomation/charts/litmus-uns --untar
```
#### Generate and apply the secret before deployment
It is assumed that the chart will be deployed to namespace `uns` and release name is `uns`
````
helm template -n uns uns litmus-uns --show-only templates/creds-secret.yaml | kubectl -n uns apply -f - 
````

#### Disable secret creation during deployment 
Deploy the chart with the following parameters

```shell
secrets:
  create: false
```

## Configuration and Installation Details

### SSL Certificate Setup for UNS

This Helm chart configures SSL/TLS for the Litmus UNS service using Kubernetes secrets. Below are the detailed steps and configurations for setting up SSL certificates.

#### Default SSL Certificate

By default, the Helm chart deploys with a self-signed SSL certificate. This certificate is stored in a Kubernetes secret and is generated during deployment. Here are the specifics:

- **Secret Name:** The name of the Kubernetes secret used for the SSL certificate is specified by the Helm parameter `luns.tlsSecretName`.
- **Certificate Validity:** The default Time To Live (TTL) of the certificate is specified by `luns.tls.ttl` and defaults to 390 days.
- **DNS and IP Configuration:**
  - **DNS Alternative Names:** Configured using `luns.tls.altNames` with a default value of `uns.local`.
  - **IP Addresses:** The default IP is `127.0.0.1`, set via `luns.tls.ipList`.

#### Binding a Static IP to the SSL Certificate

For information on how to create a static IP and bind it to a Load Balancer service in Azure, refer to this [Azure manual](https://learn.microsoft.com/en-us/azure/aks/static-ip). For this Helm chart, annotations for the Load Balancer service can be set via the Helm parameter `service.annotations`.

#### Custom SSL Certificate

Users may also provide their own SSL certificate obtained from an SSL certificate provider. To use a custom certificate:

1. Create a Kubernetes secret with your SSL certificate and private key.
2. Update the Helm chart values to use the name of your new secret by setting `luns.tlsSecretName` to the name of your created secret.

Example command to create a Kubernetes secret with your SSL certificate:

```shell
kubectl create secret generic ca-secret --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt
```

Deploy the chart with the following parameters

```shell
luns:
  tlsSecretName: "luns-default-tls"
```


### Using External Database for UNS

The Helm chart deploys a PostgreSQL database server for convenience. However, it's possible to use an external database, such as a managed database from a cloud provider, which might offer more reliability.

To use an external PostgreSQL database, set the following chart parameters:
```
postgres:
  enabled: false
  external:
    enabled: true
    host: "host"
    port: 5432
    secretName: ext-db-creds
```

Here,
- `host` is the PostgreSQL database server hostname.
- `port` is the PostgreSQL database server port.
- `secretName` is the Kubernetes secret containing the database administrator credentials, which can be created with the following command:
```
kubectl -n uns create secret generic ext-db-creds --from-literal=POSTGRES_USER='your-postgres-username' --from-literal=POSTGRES_PASSWORD='your-postgres-password'
```

#### Example for Google Cloud SQL

Follow the instructions to deploy an instance of Cloud SQL for PostgreSQL:
https://cloud.google.com/sql/docs/postgres

In this example, we will use the Cloud SQL Auth Proxy:
https://cloud.google.com/sql/docs/postgres/connect-kubernetes-engine

Create a secret with the service account key created for Cloud SQL Auth Proxy:
```
kubectl -n uns create secret generic cloud-sql-instance-credentials \
  --from-file=credentials.json=/path/to/your/service-account-key.json
```

Create a file `cloudsql-proxy.yaml` with the following content, replacing `GOOGLE_PROJECT:CLOUDSQL_ZONE:CLOUDSQL_INSTANCE` with actual values:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudsql-proxy
  labels:
    app: cloudsql-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudsql-proxy
  template:
    metadata:
      labels:
        app: cloudsql-proxy
    spec:
      containers:
      - name: cloudsql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:latest
        command: ["/cloud_sql_proxy",
                  "-instances=GOOGLE_PROJECT:CLOUDSQL_ZONE:CLOUDSQL_INSTANCE=tcp:0.0.0.0:5432",
                  "-credential_file=/secrets/cloudsql/credentials.json"]
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /secrets/cloudsql
          readOnly: true
      volumes:
      - name: cloudsql-instance-credentials
        secret:
          secretName: cloud-sql-instance-credentials

---
apiVersion: v1
kind: Service
metadata:
  name: cloudsql-proxy
  labels:
    app: cloudsql-proxy
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: cloudsql-proxy
```

Create the Cloud SQL Auth Proxy deployment in the namespace where the chart will be installed:
```
kubectl -n uns apply -f cloudsql-proxy.yaml
```

Deploy the chart with the following parameters:
```
postgres:
  enabled: false
  external:
    enabled: true
    host: "cloudsql-proxy"
    port: 5432
    secretName: ext-db-creds
```


### Upgrade

Before upgrading from single mode to cluster mode (parameter mqtt.replicaCount > 1) and vice versa, it's recommended to scale down the MQTT StatefulSet to zero.

For example

```
kubectl -n uns scale statefulset mqtt --replicas=0
```

### Backup and restore

TBD 

## Uninstalling the Chart

To uninstall the chart with the release name `uns` in the namespace `uns`:

```console
helm uninstall uns --namespace uns
```

As Kubernetes doesn't delete Persistent Volume Claims (PVCs) of StatefulSets automatically, make sure that the PVCs are deleted:

```console
PVCs=$(kubectl get pvc -o jsonpath='{.items[*].metadata.name}' -l app=uns -n uns)

for pvc in $PVCs; do
  kubectl delete pvc $pvc -n uns
done
```
#!/bin/bash

# Define variables
REGISTRY_URL="https://docker.io"
IMAGE_NAMES=("app-one" "app-two")
TAG="v1"

# Read Docker registry username and password from file
source docker_credentials.txt

# Login to Docker registry
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin $REGISTRY_URL

# Loop over each image and push it to registry
for IMAGE_NAME in "${IMAGE_NAMES[@]}"; do
    # Step 1: Build Docker image
    docker build -t $IMAGE_NAME:$TAG -f ./$IMAGE_NAME/dockerfile .

    # Step 2: Tag Docker image
    docker tag $IMAGE_NAME:$TAG $DOCKER_USERNAME/$IMAGE_NAME:$TAG

    # Step 3: Push Docker image to registry
    docker push $DOCKER_USERNAME/$IMAGE_NAME:$TAG
done

# Deploy app-one and app-two
helm install app-one-chart ./deploy-app-one -f ./deploy-app-one/values.yaml
helm install app-two-chart ./deploy-app-two -f ./deploy-app-two/values.yaml
sleep 5

# Get URLs for app-one and app-two
export POD_NAME1=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=deploy-app-one,app.kubernetes.io/instance=app-one-chart" -o jsonpath="{.items[0].metadata.name}")
export POD_NAME2=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=deploy-app-two,app.kubernetes.io/instance=app-two-chart" -o jsonpath="{.items[0].metadata.name}")

# Loop until both pods are in the running state
while true; do
    # Check if the first pod is in the running state
    if kubectl get pod $POD_NAME1 -o jsonpath='{.status.phase}' | grep -q "Running"; then
        # Check if the second pod is in the running state
        if kubectl get pod $POD_NAME2 -o jsonpath='{.status.phase}' | grep -q "Running"; then
            # Both pods are running
            echo "Both pods are running...."
            export CONTAINER_PORT2=$(kubectl get pod --namespace default $POD_NAME2 -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
            export CONTAINER_PORT1=$(kubectl get pod --namespace default $POD_NAME1 -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
            break  # Exit the loop since both pods are running
        fi
    fi
    
    # If any pod is not in the running state, wait and try again
    echo "One or both pods are not running. Waiting..."
    sleep 5
done

# Port-forwarding
kubectl --namespace default port-forward $POD_NAME1 8080:$CONTAINER_PORT1 &
kubectl --namespace default port-forward $POD_NAME2 8081:$CONTAINER_PORT2 &
sleep 5

# Add a separator for outputs of the applications
echo "-------------------------------------"

# Curl the URL of the first application
echo "Output of App One:"
curl -s "http://127.0.0.1:8080"

# Add a separator between the outputs of the two applications
echo "-------------------------------------"

# Curl the URL of the second application
echo "Output of App Two:"
curl -s "http://127.0.0.1:8081"

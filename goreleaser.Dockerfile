
ARG ProjectName=synology-csi
ARG GOOS=linux
ARG GOARCH=amd64

# FROM alpine:latest
FROM golang:1.17-alpine

WORKDIR /

ENTRYPOINT ["/synology-csi"]
# COPY "./dist/${ProjectName}_${GOARCH}_${GOOS}/${ProjectName}" "/synology-csi"
COPY "dist/synology-csi_darwin_amd64/synology-csi" "/synology-csi"

FROM scratch

COPY /synology-csi /synolgoy-csi-driver

ENTRYPOINT ["/synology-csi-driver"]

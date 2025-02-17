# Synology CSI Driver for Kubernetes

## Fork Note 

This fork exists to build a release to dockerhub which includes ARM64.

---

The official [Container Storage Interface](https://github.com/container-storage-interface) driver for Synology NAS.

### Container Images & Kubernetes Compatibility
Driver Name: csi.san.synology.com
| Driver Version | Image                                                                 | Supported K8s Version |
| -------------- | --------------------------------------------------------------------- | --------------------- |
| v1.0.0         | [synology-csi:v1.0.0](https://hub.docker.com/r/synology/synology-csi) | 1.19                  |



The Synology CSI driver supports:
- Access Modes: Read/Write Multiple Pods
- Cloning
- Expansion
- Snapshot

## Installation
### Prerequisites
- Kubernetes versions 1.19
- Synology NAS running DSM 7.0 or above
- Go version 1.16 or above is recommended
- (Optional) Both [Volume Snapshot CRDs](https://github.com/kubernetes-csi/external-snapshotter/tree/v4.0.0/client/config/crd) and the [common snapshot controller](https://github.com/kubernetes-csi/external-snapshotter/tree/v4.0.0/deploy/kubernetes/snapshot-controller) must be installed in your Kubernetes cluster if you want to use the **Snapshot** feature

### Notice
1. Before installing the CSI driver, make sure you have created and initialized at least one **storage pool** and one **volume** on your DSM.
2. Make sure that all the worker nodes in your Kubernetes cluster can connect to your DSM.
3. After you complete the steps below, the *full* deployment of the CSI driver, including the snapshotter, will be installed. If you don’t need the **Snapshot** feature, you can install the *basic* deployment of the CSI driver instead.

### Procedure
1. Clone the git repository. `git clone https://github.com/SynologyOpenSource/synology-csi.git`
2. Enter the directory. `cd synology-csi`
3. Copy the client-info-template.yml file. `cp config/client-info-template.yml config/client-info.yml`
4. Edit `config/client-info.yml` to configure the connection information for DSM. You can specify **one or more** storage systems on which the CSI volumes will be created. Change the following parameters as needed:
    - *host*: The IPv4 address of your DSM.
    - *port*: The port for connecting to DSM. The default HTTP port is 5000 and 5001 for HTTPS. Only change this if you use a different port.
    - *https*: Set "true" to use HTTPS for secure connections. Make sure the port is properly configured as well.
    - *username*, *password*: The credentials for connecting to DSM.

5. Run `./scripts/deploy.sh run` to install the driver. This will be a *full* deployment, which means you'll be building and running all CSI services as well as the snapshotter. If you want a *basic* deployment, which doesn't include installing a snapshotter, change the command as instructed below.
    - *full*:
        `./scripts/deploy.sh run`
    - *basic*:
        `./scripts/deploy.sh build && ./scripts/deploy.sh install --basic`

    If you don’t need to build the driver locally and want to pull the [image](https://hub.docker.com/r/synology/synology-csi) from Docker instead, run the command as instructed below.

    - *full*:
        `./scripts/deploy.sh install --all`
    - *basic*:
        `./scripts/deploy.sh install --basic`

    Running the bash script will:
    - Create a namespace named "`synology-csi`". This is where the driver will be installed.
    - Create a secret named "`client-info-secret`" using the credentials from the client-info.yml you configured in the previous step.
    - Build a local image and deploy the CSI driver.
    - Create a **default** storage class named "`synology-iscsi-storage`" that uses the "`Retain`" policy.
    - Create a volume snapshot class named "`synology-snapshotclass`" that uses the "`Delete`" policy. (*Full* deployment only)

6. Check if the status of all pods of the CSI driver is Running. `kubectl get pods -n synology-csi`

## CSI Driver Configuration
Storage classes and the secret are required for the CSI driver to function properly. This section explains how to do the following things:
1. Create the storage system secret (This is not mandatory because deploy.sh will complete all the configurations when you configure the config file mentioned previously.)
2. Configure storageclasses
3. Configure volumesnapshotclasses

### Creating a Secret
Create a secret to specify the storage system address and credentials (username and password). Usually the config file sets up the secret as well, but if you still want to create the secret or recreate it, follow the instructions below:

1. Edit the config file `config/client-info.yml` or create a new one like the example shown here:
      ```
      clients:
      - host: 192.168.1.1
        port: 5000
        https: false
        username: <username>
        password: <password>
      - host: 192.168.1.2
        port: 5001
        https: true
        username: <username>
        password: <password>
      ```
    The `clients` field can contain more than one Synology NAS. Seperate them with a prefix `-`.

2. Create the secret using the following command (usually done by deploy.sh):
    ```!
    kubectl create secret -n <namespace> generic client-info-secret --from-file=config/client-info.yml
    ```

    - Make sure to replace \<namespace\> with `synology-csi`. This is the default namespace. Change it to your custom namespace if needed.
    - If you change the secret name "client-info-secret" to a different one, make sure that all files at `deploy/kubernetes/<k8s version>/` are using the secret name you set.

### Creating Storage Classes
Create and apply StorageClasses with the properties you want.

1. Create YAML files using the one at `deploy/kubernetes/<k8s version>/storage-class.yml` as the example, whose content is as below:

    ```
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      annotations:
        storageclass.kubernetes.io/is-default-class: "false"
      name: synostorage
    provisioner: csi.san.synology.com
    parameters:
      fsType: 'ext4'
      dsm: '192.168.1.1'
      location: '/volume1'
    reclaimPolicy: Retain
    allowVolumeExpansion: true
    ```
2. Configure the StorageClass properties by assigning the parameters in the table. You can also leave blank if you don’t have a preference:

    | Name       | Type   | Description                                                                                                       | Default |
    | ---------- | ------ | ----------------------------------------------------------------------------------------------------------------- | ------- |
    | *dsm*      | string | The IPv4 address of your DSM, which must be included in the `client-info.yml` for the CSI driver to log in to DSM | -       |
    | *location* | string | The location (/volume1, /volume2, ...) on DSM where the LUN for *PersistentVolume* will be created                | -       |
    | *fsType*   | string | The formatting file system of the *PersistentVolumes* when you mount them on the pods                             | 'ext4'  |

    **Notice**

    - If you leave the parameter *location* blank, the CSI driver will choose a volume on DSM with available storage to create the volumes.
    - All volumes created by the CSI driver are Thin Provisioned LUNs on DSM. This will allow you to take snapshots of them.

3. Apply the YAML files to the Kubernetes cluster.

    ```
    kubectl apply -f <storageclass_yaml>
    ```

### Creating Volume Snapshot Classes
Create and apply VolumeSnapshotClasses with the properties you want.

1. Create YAML files using the one at `deploy/kubernetes/<k8s version>/snapshotter/volume-snapshot-class.yml` as the example, whose content is as below:

    ```
    apiVersion: snapshot.storage.k8s.io/v1beta1    # v1 for kubernetes v1.20 and above
    kind: VolumeSnapshotClass
    metadata:
      name: synology-snapshotclass
      annotations:
        storageclass.kubernetes.io/is-default-class: "false"
    driver: csi.san.synology.com
    deletionPolicy: Delete
    # parameters:
    #   description: 'Kubernetes CSI'
    #   is_locked: 'false'
    ```

2. Configure volume snapshot class properties by assigning the following parameters, all parameters are optional:

    | Name          | Type   | Description                                  | Default |
    | ------------- | ------ | -------------------------------------------- | ------- |
    | *description* | string | The description of the snapshot on DSM       | ""      |
    | *is_locked*   | string | Whether you want to lock the snapshot on DSM | 'false' |

3. Apply the YAML files to the Kubernetes cluster.

    ```
    kubectl apply -f <volumesnapshotclass_yaml>
    ```

## Building & Manually Installing

By default, the CSI driver will pull the latest [image](https://hub.docker.com/r/synology/synology-csi) from Docker Hub.

If you want to use images you built locally for installation, edit all files under `deploy/kubernetes/<k8s version>/`  and make sure `imagePullPolicy: IfNotPresent` is included in every csi-plugin container.

### Building
- To build the CSI driver, execute `make`.
- To build the *synocli* dev tool, execute `make synocli`. The output binary will be at `bin/synocli`.
- To run unit tests, execute `make test`.
- To build a docker image, run `./scripts/deploy.sh build`.
 Afterwards, run `docker images` to check the newly created image.

### Installation

- To install all pods of the CSI driver, run `./scripts/deploy.sh install --all`
- To install pods of the CSI driver without the snapshotter, run `./scripts/deploy.sh install --basic`
- Run `./scripts/deploy.sh --help` to see more information on the usage of the commands.

### Uninstallation
If you are no longer using the CSI driver, make sure that no other resources in your Kubernetes cluster are using storage managed by Synology CSI driver before uninstalling it.
- `./scripts/uninstall.sh`


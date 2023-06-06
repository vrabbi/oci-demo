#!/bin/bash
########################
# include the magic
########################
. demo-magic.sh

# some supporting functions


DEMO_PROMPT='[vrabbi@oci-demo ${PWD##*/}]# '

function prompt
{
    echo; echo "------> $*"
    echo;
}

# hide the evidence
clear

prompt Lets first create a local docker registry
pei "docker run -d -p 5000:5000 --restart=always --name registry registry:2"
wait
prompt Now, lets create a base directory to work in
pe "mkdir -p oci-demo/bin"
pei "cd oci-demo/bin"
wait
clear

prompt Next we will download and configure the busybox files for our image
pei "wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox"
pei "chmod 777 busybox"
pei "ln -s busybox cat"
pei "ln -s busybox echo"
pei "ln -s busybox env"
pei "ln -s busybox ls"
pei "ln -s busybox mkdir"
pei "ln -s busybox rm"
pei "ln -s busybox rmdir"
pei "ln -s busybox sh"
pei "ln -s busybox whoami"
pei "cd .."
wait
clear
prompt Now, lets create the OCI base directory
pe "mkdir -p output-image"

prompt Now, we need to package up the busybox files
pe "tar cvf output-image/layer.tar bin"
wait
clear
prompt We now need to calculate the checksum and size of the layer we just created
pe 'layer_checksum=$(shasum -a 256 output-image/layer.tar | cut -d" " -f1)'
p "layer_size=\$(wc -c output-image/layer.tar | awk '{print \$1}')"
layer_size=$(wc -c output-image/layer.tar | awk '{print $1}')
pei 'echo $layer_checksum $layer_size'
wait
prompt Now, we need to create the Image Blob directory
pei "mkdir -p output-image/blobs/sha256"
wait
prompt Lets move the layer to the correct path and name it correctly
pei 'mv output-image/layer.tar output-image/blobs/sha256/$layer_checksum'
pei 'ls output-image/blobs/sha256'
wait
prompt Now, we need to create are config file for the image
p 'cat <<EOF > output-image/config.json
{
  "architecture": "amd64",
  "os": "linux",
  "config": {
    "Env": ["PATH=/bin"],
    "WorkingDir": "/"
  },
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:'${layer_checksum}'"
    ]
  }
}
EOF'
cat <<EOF > output-image/config.json
{
  "architecture": "amd64",
  "os": "linux",
  "config": {
    "Env": ["PATH=/bin"],
    "WorkingDir": "/"
  },
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:${layer_checksum}"
    ]
  }
}
EOF
wait
clear
prompt Now we need to calculate the checksum and size of the config.json file
pe 'config_checksum=$(shasum -a 256 output-image/config.json | cut -d" " -f1)'
pe 'config_size=$(wc -c output-image/config.json | cut -d" " -f1)'
wait
prompt Now, lets move the config.json to the correct path and name it correctly
pei 'mv output-image/config.json output-image/blobs/sha256/$config_checksum'
wait
clear
prompt Now we need to create the OCI image manifest
p 'cat <<EOF > output-image/manifest.json
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:'${config_checksum}'",
    "size": '${config_size}'
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:'${layer_checksum}'",
      "size": '${layer_size}'
    }
  ]
}
EOF'
cat <<EOF > output-image/manifest.json
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:${config_checksum}",
    "size": ${config_size}
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:${layer_checksum}",
      "size": ${layer_size}
    }
  ]
}
EOF
wait
clear
prompt Now, lets calculate the checksum and size of the manifest.json file
pe 'manifest_checksum=$(shasum -a 256 output-image/manifest.json | cut -d" " -f1)'
pe 'manifest_size=$(wc -c output-image/manifest.json | cut -d" " -f1)'

prompt Now, lets move the manifest.json to the correct path and name it correctly
pei 'mv output-image/manifest.json output-image/blobs/sha256/$manifest_checksum'
wait
clear
prompt Now, we need to create the index.json for our image
p 'cat <<EOF > output-image/index.json
{
  "schemaVersion": 2,
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:'${manifest_checksum}'",
      "size": '${manifest_size}'
    }
  ]
}
EOF'
cat <<EOF > output-image/index.json
{
  "schemaVersion": 2,
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:${manifest_checksum}",
      "size": ${manifest_size}
    }
  ]
}
EOF
wait
clear
prompt Now, the last file we need to create is the OCI Layout file
p 'cat <<EOF > output-image/oci-layout
{
  "imageLayoutVersion": "1.0.0"
}
EOF'
cat <<EOF > output-image/oci-layout
{
  "imageLayoutVersion": "1.0.0"
}
EOF
wait
clear

prompt Lets take a look at the file structure we have built
pei 'tree output-image'
wait
clear

prompt Now lets push our image to the local registry
pei 'crane push output-image localhost:5000/sample-oci-demo:0.0.1'
wait
prompt And now we can run the image
pei 'docker run --name oci-demo-container -it localhost:5000/sample-oci-demo:0.0.1 sh'
echo 'Demo environment is being cleaned up...'
docker kill registry
docker rm oci-demo-container registry
docker rmi registry:2 localhost:5000/sample-oci-demo:0.0.1
cd ..
rm -rf oci-demo

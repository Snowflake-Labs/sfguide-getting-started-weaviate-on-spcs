FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

ARG TARGETARCH
ARG GOFLAGS="'-ldflags=-w -s'"

WORKDIR /go/src/github.com/jmorganca/ollama
RUN apt-get update && apt-get install -y git build-essential cmake
ADD https://dl.google.com/go/go1.21.3.linux-$TARGETARCH.tar.gz /tmp/go1.21.3.tar.gz
RUN mkdir -p /usr/local && tar xz -C /usr/local </tmp/go1.21.3.tar.gz

COPY . .
ENV GOARCH=$TARGETARCH
ENV GOFLAGS=$GOFLAGS
RUN /usr/local/go/bin/go generate ./... \
    && /usr/local/go/bin/go build .

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates
COPY --from=0 /go/src/github.com/jmorganca/ollama/ollama /bin/ollama
EXPOSE 11434
ENV OLLAMA_HOST 0.0.0.0

# set some environment variable for better NVIDIA compatibility
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Set the working directory
WORKDIR /workspace/

# For Jupyter only
EXPOSE  8888
RUN apt-get update && apt-get install -y \
    python3-pip

COPY --chmod=777 requirements-snowflake.txt Create_Product_Descriptions.ipynb startup.sh ./ 
# Install the dependencies from the requirements-snowflake.txt file
RUN pip3 install --no-cache-dir --upgrade pip
RUN pip3 install --no-cache-dir -r requirements-snowflake.txt
RUN mkdir /workspace/.local /workspace/.cache && chmod 777 -R Create_Product_Descriptions.ipynb
RUN python3 -m notebook --ip='*' --port=8888 --no-browser --allow-root

ENTRYPOINT ["./startup.sh"]


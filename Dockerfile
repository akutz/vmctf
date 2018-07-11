FROM alpine:3.7
LABEL maintainer="Andrew Kutz <akutz@vmware.com>"

ENV TF_VERSION=0.11.7

# Install some common dependencies
RUN apk --no-cache add curl tar

# Install the Terraform binary
RUN curl -sSLO \
    "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" && \
    unzip "terraform_${TF_VERSION}_linux_amd64.zip" -d /usr/local/bin

# Copy the contents into the container
RUN mkdir -p /tf
COPY *.tf entrypoint.sh /tf/
RUN chmod +x /tf/entrypoint.sh

# Copy the systems into the container
COPY ldap/ /tf/ldap/
RUN chmod +x /tf/*/deploy.sh /tf/*/destroy.sh 2> /dev/null || true

WORKDIR /tf/

CMD ["shell"]
ENTRYPOINT ["/tf/entrypoint.sh"]
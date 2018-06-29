FROM alpine:3.7
LABEL maintainer="Andrew Kutz <akutz@vmware.com>"

# Install OpenLDAP
RUN apk --no-cache add openldap openldap-clients openldap-back-mdb

# Remove the default OpenLDAP config file.
RUN rm -f /etc/openldap/slapd.conf

# Create the required directories for an OpenLDAP server.
RUN mkdir -p /run/openldap \
             /var/lib/openldap/openldap-data \
             /etc/openldap/ldif

# Remove the package cache to free space.
RUN rm -fr /var/cache/apk/*

# Files in the /ldif directory are added to the LDAP server.
VOLUME ["/ldif", "/var/lib/openldap/openldap-data"]

# Expose the standard LDAP ports.
EXPOSE 389
EXPOSE 636

# Copy the entrypoint script into the container.
RUN mkdir -p /var/lib/slapd
COPY slapd.sh /var/lib/slapd/
RUN chmod +x /var/lib/slapd/slapd.sh

# With no default arguments the entrypoint will run slapd in the
# foreground. An argument of "shell" causes the container to drop
# into the shell with everything set up to run slapd.
ENTRYPOINT ["/var/lib/slapd/slapd.sh"]
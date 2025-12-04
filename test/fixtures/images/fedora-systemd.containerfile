FROM fedora:43

# Install systemd for testing systemd integration
RUN dnf install -y systemd && dnf clean all

# Remove unnecessary systemd services to speed up boot in tests
RUN systemctl mask systemd-logind.service \
    systemd-networkd.service \
    systemd-resolved.service \
    systemd-hostnamed.service \
    systemd-localed.service \
    systemd-timedated.service

CMD ["/usr/sbin/init"]

# KNOWN_LIMITS.md - Technical Constraints and Known Limits

This document records deliberate trade-offs, scope boundaries, and known technical limitations of Zohal Connect according to Rule R1.

## 1. Local SOCKS5 Proxy Ports
- Aether opens local proxy listeners on loopback (`127.0.0.1`) without password authentication.
- **Mitigation**: Random ports are probed in the 20000-59999 range per session and bound strictly to loopback (`127.0.0.1`), preventing remote network access.

## 2. Soft Kill Switch
- The kill switch operates at the tunnel engine layer: when upstream connection is lost or reconnecting, the TUN interface drops all outbound traffic.
- If the `zohald` service process is forcibly killed (`kill -9`) or crashes, the OS removes the virtual TUN interface, temporarily exposing direct connectivity until the service restarts and runs journal recovery.

## 3. Windows Domain-Based Routing (Plan B)
- In Windows TUN mode without the `IP_UNICAST_IF` patch (Plan B), domain-based direct routing cannot be sniffed without causing routing loops with Aether's outbound connections.
- In this configuration, domain-based direct rules in the UI are disabled with a clear Persian explanation, while CIDR and IP-based bypass routes function at the OS level.

## 4. UDP / QUIC SNI Sniffing
- Domain routing rules (`--route-direct`) rely on TLS ClientHello SNI sniffing on TCP port 443.
- QUIC / UDP destination sniffing is not supported by upstream Aether. QUIC connections fall back to IP/CIDR routing or transit the tunnel.

## 5. Non-systemd Linux Distributions
- On Linux, the system TUN mode requires `systemd` (`Type=notify`, `zohald.service`, `sd-notify`).
- Non-systemd distributions (e.g., Alpine, Void) are not supported for TUN mode in v1; user proxy scope (`zohald user`) may be used instead.

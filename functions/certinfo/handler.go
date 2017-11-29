package function

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"
)

func Handle(req []byte) string {
	request := strings.ToLower(string(req))
	if !strings.HasPrefix(request, "http") {
		request = "https://" + request
	}

	u, err := url.Parse(request)
	if err != nil {
		return fmt.Sprintf("Error: %v", err)
	}

	address := u.Hostname() + ":443"
	ipConn, err := net.DialTimeout("tcp", address, 2*time.Second)
	if err != nil {
		return fmt.Sprintf("Dial error: %v", err)
	}

	defer ipConn.Close()
	conn := tls.Client(ipConn, &tls.Config{
		InsecureSkipVerify: true,
	})
	if err = conn.Handshake(); err != nil {
		return fmt.Sprintf("Handshake error: %v", err)
	}

	defer conn.Close()
	addr := conn.RemoteAddr()
	host, port, err := net.SplitHostPort(addr.String())
	if err != nil {
		return fmt.Sprintf("Error: %v", err)
	}

	cert := conn.ConnectionState().PeerCertificates[0]
	return fmt.Sprintf("Host %v\nPort %v\nIssuer %v\nCommonName %v\nNotBefore %v\nNotAfter %v\nSANs %v\n",
		host, port, cert.Issuer.CommonName, cert.Subject.CommonName, cert.NotBefore, cert.NotAfter, cert.DNSNames)
}

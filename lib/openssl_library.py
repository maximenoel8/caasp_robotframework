#!/usr/bin/python3
# -*- coding: utf-8 -*-

import logging
from collections import OrderedDict

import ipaddress
from OpenSSL import crypto
from pyasn1.codec.der.decoder import decode as asn1_decoder
# Import native Python type encoder
from pyasn1.codec.native.encoder import encode as nat_encoder
# Import SubjectAltName from rfc2459 module
from pyasn1_modules.rfc2459 import SubjectAltName

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.DEBUG)


def _get_san(san):
    element = []
    for d in san["dns"]:
        logging.debug("Dns :" + d)
        element.append('DNS:{}'.format(d))
    for d in san["ip"]:
        logging.debug("Ip :" + d)
        element.append('IP:{}'.format(d))
    logging.debug(element)
    sans = ', '.join(element)
    return str(sans)


def _write_key_certificate(CERT_FILE, KEY_FILE, certificate, key):
    with open(CERT_FILE, "wt") as f:
        f.write(crypto.dump_certificate(crypto.FILETYPE_PEM, certificate).decode("utf-8"))
    with open(KEY_FILE, "wt") as f:
        f.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, key).decode("utf-8"))


def _create_x509_extension(SAN):
    sans = _get_san(SAN)
    extensions = [
        crypto.X509Extension(b"basicConstraints",
                             True,
                             b"CA:FALSE"),

        crypto.X509Extension(b"keyUsage",
                             True,
                             b"digitalSignature,keyEncipherment, keyAgreement"),

        crypto.X509Extension(b"subjectAltName",
                             False,
                             bytes(sans, "utf-8"))
    ]
    return extensions


def _create_key_pair():
    k = crypto.PKey()
    k.generate_key(crypto.TYPE_RSA, 2048)
    return k


def _load_certificate(CERT_FILE):
    st_cert = open(CERT_FILE, 'rt').read()
    cert = crypto.load_certificate(crypto.FILETYPE_PEM, st_cert)
    return cert


def _load_key(KEY_FILE):
    st_key = open(KEY_FILE, 'rt').read()
    key = crypto.load_privatekey(crypto.FILETYPE_PEM, st_key)
    return key


# a certificate signing request (csr)
def generate_signed_ssl_certificate(service, CERT_FILE, KEY_FILE, CA_cert_file, CA_key_file, start_date, end_date, SAN):
    logging.debug(SAN)

    cacert = _load_certificate(CA_cert_file)
    cakey = _load_key(CA_key_file)

    psec = _create_key_pair()
    # a certificate signing request (csr)
    csrrequest = crypto.X509Req()
    csrrequest.get_subject()
    csrrequest.get_subject().CN = service
    csrrequest.set_pubkey(psec)
    csrrequest.set_version(2)

    selfsignedcert = crypto.X509()
    selfsignedcert.set_serial_number(12345)
    selfsignedcert.set_notBefore(bytes(start_date, "utf-8"))
    selfsignedcert.set_notAfter(bytes(end_date, "utf-8"))
    selfsignedcert.set_subject(csrrequest.get_subject())
    selfsignedcert.set_issuer(cacert.get_subject())
    selfsignedcert.set_version(2)
    selfsignedcert.set_pubkey(csrrequest.get_pubkey())
    selfsignedcert.add_extensions(_create_x509_extension(SAN))
    selfsignedcert.sign(cakey, "sha256")
    _write_key_certificate(CERT_FILE, KEY_FILE, selfsignedcert, psec)


def generate_self_signed_ssl_certificate(service, CERT_FILE, KEY_FILE, start_date, end_date, SAN):
    key = _create_key_pair()

    # create a self-signed cert
    cert = crypto.X509()
    cert.get_subject().CN = service
    cert.set_serial_number(1000)
    cert.set_notBefore(bytes(start_date, "utf-8"))
    cert.set_notAfter(bytes(end_date, "utf-8"))
    cert.set_issuer(cert.get_subject())
    cert.add_extensions(_create_x509_extension(SAN))
    cert.set_version(2)
    cert.set_pubkey(key)
    cert.sign(key, 'sha256')
    _write_key_certificate(CERT_FILE, KEY_FILE, cert, key)


def get_san_from_cert(CERT_FILE):
    cert = _load_certificate(CERT_FILE)
    e = cert.get_extension(2)
    if e.get_short_name().decode() != "subjectAltName":
        logging.error("extension not subjectAltName")

    raw_alt_names = e.get_data()
    decoded_alt_names, _ = asn1_decoder(raw_alt_names, asn1Spec=SubjectAltName())
    py_alt_names = nat_encoder(decoded_alt_names)
    logging.debug(py_alt_names)
    ip_sub_alt_name = []
    dns_sub_alt_name = []
    for element in py_alt_names:
        if element.keys() == OrderedDict([('iPAddress', '_')]).keys():
            ip_sub_alt_name.append(str(ipaddress.IPv4Address(element['iPAddress'])))
        elif element.keys() == OrderedDict([('dNSName', '_')]).keys():
            dns_sub_alt_name.append(element['dNSName'].decode("utf-8"))
        else:
            logging.error("Bad AltName Key")
    logging.debug(ip_sub_alt_name)
    logging.debug(dns_sub_alt_name)
    result = {"dns": dns_sub_alt_name,
              "ip": ip_sub_alt_name}
    logging.debug(result)
    return result


def get_expiry_date(CERT_FILE):
    cert = _load_certificate(CERT_FILE)
    logging.debug(cert.get_notAfter().decode())
    return cert.get_notAfter().decode()


def verify_certificate_chain(cert_path, trusted_certs):
    # Download the certificate from the url and load the certificate
    certificate = _load_certificate(cert_path)

    # Create a certificate store and add your trusted certs
    try:
        store = crypto.X509Store()

        # Assuming the certificates are in PEM format in a trusted_certs list
        for _cert in trusted_certs:
            client_certificate = _load_certificate(_cert)
            store.add_cert(client_certificate)

        # Create a certificate context using the store and the downloaded certificate
        store_ctx = crypto.X509StoreContext(store, certificate)

        # Verify the certificate, returns None if it can validate the certificate
        logging.debug(store_ctx.verify_certificate())

        return True

    except Exception as e:
        print(e)
        return False


def get_issuer(CERT_FILE):
    cert = _load_certificate(CERT_FILE)
    subject = cert.get_issuer()
    subject_str = "".join("/{0:s}={1:s}".format(name.decode(), value.decode()) for name, value in subject.get_components())
    logging.debug(subject_str)
    return subject_str

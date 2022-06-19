import pytest

from schematics.datastructures import Context
from schematics.exceptions import ConversionError, DataError, ValidationError
from schematics.models import Model
from schematics.types import *


def test_ipv4_type():
    assert IPv4Type().validate("255.255.255.255")
    with pytest.raises(ValidationError):
        IPv4Type().validate("1")
    with pytest.raises(ValidationError):
        IPv4Type().validate("255.256.255.255")
    with pytest.raises(ValidationError):
        IPv4Type().validate("255.255.255.2555")

    mock = IPv4Type(required=True).mock()
    assert IPv4Type().validate(mock)


def test_ipv6_type():
    field = IPv6Type()

    addrs = [
        "fe80::223:6caf:fe76:c12d",
        "2001:14ba:ff:a000:223:6caf:fe76:c12d",
        "::255.255.255.255",
        "::1",
    ]
    for addr in addrs:
        field.validate(addr)

    addrs = [
        "",
        "::255.256.255.255",
        ":255.255.255.255",
        "2001:ff:a000:223:6caf:fe76:c12d",
        "fe80::223:6caff:fe76:c12d",
    ]
    for addr in addrs:
        with pytest.raises(ValidationError):
            field.validate(addr)

    mock = IPv6Type(required=True).mock()
    assert IPv6Type().validate(mock)


def test_ip_type():
    assert IPAddressType().validate("255.255.255.255")
    assert IPAddressType().validate("fe80::223:6caf:fe76:c12d")

    mock = IPAddressType(required=True).mock()
    assert IPAddressType().validate(mock)


def test_mac_type():
    addrs = [
        "00-00-00-00-00-00",
        "03:0F:25:B7:10:1E",
        "030F25B7104E",
        "030F25:B7104E",
        "030F25-B7104E",
        "030F.25B7.104E",
    ]
    for addr in addrs:
        assert MACAddressType().validate(addr)

    addrs = [
        "00-00-00-00-00",
        "00:00-00-00-00-00",
        "00:00-00-00-00-00",
        "030F25B7104",
        "030F25B7104Z",
        "30F25:B7104E",
        "030F2-B7104E",
        "030F:25B7.104E",
    ]
    for addr in addrs:
        with pytest.raises(ValidationError):
            MACAddressType().validate(addr)

    mock = MACAddressType(required=True).mock()
    assert MACAddressType().validate(mock)

    s = MACAddressType().to_primitive(value="00-00-00-00-00-00")
    assert MACAddressType().validate(s)


def test_url_type_with_valid_urls():

    field = URLType()
    urls = [
        "https://x." + "x" * 63 + ".com",
        "https://123456789." + ("x" * 59 + ".") * 4 + "com",  # len = 253
        "https://123456789." + ("x" * 59 + ".") * 4 + "com.",  # len = 253 + '.'
        "https://example.fi",
        "http://foo-bar.example.com",
        "HTTP://example.com:80",
        "http://-user:123:%:456(z)@example.com:80",
        "http://example.com/a/b/../c+d/e;f/~jdoe/@?q(x=1;y=2)&r=0#yo!",
        "http://example.com./a/",
        "http://crème-brûlée.tld/menu/à%20la%20carte/",
        "http://はじめよう.みんな",
        "http://xn--p8j9a0d9c9a.xn--q9jyb4c",
        "http://∫ç√œΩ@example.com/?µ=0.3&∂=0.1",
        "http://user:123@127.0.0.1",
        "http://127.0.0.1:99999/",
        "http://127.0.0.1:99999/qweasd",
        "http://[2001:4802:7901::e60a:1375:0:5]",
        "http://[2001:4802:7901::e60a:1375:0:5]:99999",
    ]
    for url in urls:
        field.validate(url)

    field = URLType(fqdn=False)
    urls = [
        "https://1",
        "https://111.q2w",
        "https://localhost",
    ]
    for url in urls:
        field.validate(url)


def test_url_type_with_invalid_url():

    field = URLType()
    urls = [
        "https://1",
        "https://111.q2w",
        "https://localhost",
        "http:example.com",
        "https://example.f",
        "https://example.fi0",
        "ftp://example.com",
        "https://x." + "x" * 64 + ".com",
        "https://1234567890." + ("x" * 59 + ".") * 4 + "com",  # len = 254
        "http://-foobar.example.com",
        "http://qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq-.example.com",
        "http://example.com../a/",
        "http://ex..ample.com/a/",
        "http://.example.com/a/",
        "http://exam%70le.com/a/",
        "http://example.com|/a/",
        "http://example.com/a b/",
        "http://foo_bar.example.com",
        "http://xn--abcdäedfg.xn--q9jyb4c",  # ACE prefix + non-ASCII character
        "http://example.com/a/\x7F",  # illegal ASCII character
        "http://127.0.0.1:999999/",
        "http://2001:4802:7901::e60a:1375:0:5",
    ]
    for url in urls:
        with pytest.raises(ValidationError):
            field.validate(url)


def test_url_type_with_unreachable_url():
    with pytest.raises(ValidationError):
        URLType(verify_exists=True).validate("http://127.0.0.1:99999/")


def test_email_type_with_valid_addresses():
    field = EmailType()
    addrs = [
        r'"()\\\<>[]:,;@!\"#$%&*+-/=?^_`{}|~.a"@example.org',
        '"foo bar baz"@example.org',
        "Z@foo.zz",
        "123.qwe.asd@foo.bar.baz",
    ]
    for addr in addrs:
        field.validate(addr)


def test_email_type_with_invalid_addresses():
    field = EmailType()
    addrs = [
        r'"qweasd\"@example.org',
        '"qwe"asd"@example.org',
        "curaçao@example.org",
        "foo@local",
    ]
    for addr in addrs:
        with pytest.raises(ValidationError):
            field.validate(addr)

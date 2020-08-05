#!/usr/bin/python3
# Use selenium to get kubeconfig from gangway

from selenium import webdriver


def get_firefox_profile():
    browser_profile = webdriver.FirefoxProfile()
    browser_profile.accept_untrusted_certs = True
    browser_profile.assume_untrusted_cert_issuer = True
    browser_profile.set_preference("browser.download.folderList", 2)
    browser_profile.set_preference("browser.download.dir", "/home/seluser/Downloads/")
    browser_profile.set_preference("browser.helperApps.neverAsk.saveToDisk", "text/plain")
    browser_profile.set_preference("browser.download.manager.alertOnEXEOpen", False)
    browser_profile.set_preference("browser.download.manager.closeWhenDone", False)
    browser_profile.set_preference("browser.download.manager.focusWhenStarting", False)
    return browser_profile

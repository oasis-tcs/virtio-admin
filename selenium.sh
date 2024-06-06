test -f geckodriver-v0.34.0-linux64.tar.gz || wget https://github.com/mozilla/geckodriver/releases/download/v0.34.0/geckodriver-v0.34.0-linux64.tar.gz
tar xvzf geckodriver-v0.34.0-linux64.tar.gz
test -f selenium-server-4.21.0.jar || wget https://github.com/SeleniumHQ/selenium/releases/download/selenium-4.21.0/selenium-server-4.21.0.jar
java -Dwebdriver.gecko.driver=$(pwd)/geckodriver  -jar selenium-server-4.21.0.jar  standalone --host 0.0.0.0

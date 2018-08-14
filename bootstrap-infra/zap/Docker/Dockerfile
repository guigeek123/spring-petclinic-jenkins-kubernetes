FROM python 
COPY pen-test-app.py .
RUN mkdir steps
COPY steps/pen-test.py steps/
COPY pen-test.feature .
RUN chmod +x pen-test-app.py
RUN pip install python-owasp-zap-v2.4
RUN pip install behave
FROM python:3.10.10-alpine3.17
WORKDIR /src
COPY . /src
RUN apk update && \
    apk upgrade && \
    apk add py3-pip
RUN pip install -r requirements.txt
CMD ["uvicorn", "app:app", "--port", "8443"]
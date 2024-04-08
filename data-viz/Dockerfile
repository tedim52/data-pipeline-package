FROM python:3.8

WORKDIR /usr/app
ADD ./requirements.txt ./

# shouldn't python already come with pip?
RUN python -m pip install --upgrade pip && \
    pip install -r requirements.txt && \
    useradd -ms /bin/bash -g users sfu && \
    chown -R sfu:users /usr/app

# whats the point of having an additional user?    
USER sfu

COPY --chown=sfu:users python .

RUN jupyter trust blog-visuals.ipynb
ENTRYPOINT ["jupyter", "notebook", "--paths='/usr/app'","--port=8888", "--no-browser", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''","--allow-root"]
CMD ["blog-visuals.ipynb"]
#!/bin/bash

LOCAL_PORT=
REMOTE_PORT=
REMOTE_USER=
REMOTE_HOST=

# Start the SSH tunnel
echo "Creating SSH tunnel..."
ssh -L $LOCAL_PORT:localhost:$REMOTE_PORT -N -f $REMOTE_USER@$REMOTE_HOST

ssh $REMOTE_USER@$REMOTE_HOST start_headless.sh

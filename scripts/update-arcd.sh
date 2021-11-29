#!/bin/bash

# Pulling latest from LibVF.IO
git pull

# Recompile & install arcd from updated sources
nimble install -y

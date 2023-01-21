import os
import glob
import sys
import functools
import jsonpickle
from collections import OrderedDict
from Orange.widgets import widget, gui, settings
import Orange.data
from Orange.data.io import FileFormat
from DockerClient import DockerClient
from BwBase import OWBwBWidget, ConnectionDict, BwbGuiElements, getIconName, getJsonName
from PyQt5 import QtWidgets, QtGui

class OWdocker_metrics(OWBwBWidget):
    name = "docker_metrics"
    description = "Collect docker metrics"
    priority = 1
    icon = getIconName(__file__,"bash.png")
    want_main_area = False
    docker_image_name = "biodepot/docker-metrics"
    docker_image_tag = "0.1__alpine-3.17.1"
    inputs = [("workflow",str,"handleInputsworkflow"),("stop_metrics",str,"handleInputsstop_metrics")]
    pset=functools.partial(settings.Setting,schema_only=True)
    runMode=pset(0)
    exportGraphics=pset(False)
    runTriggers=pset([])
    triggerReady=pset({})
    inputConnectionsStore=pset({})
    optionsChecked=pset({})
    workflow=pset("workflow")
    stop_metrics=pset(False)
    def __init__(self):
        super().__init__(self.docker_image_name, self.docker_image_tag)
        with open(getJsonName(__file__,"docker_metrics")) as f:
            self.data=jsonpickle.decode(f.read())
            f.close()
        self.initVolumes()
        self.inputConnections = ConnectionDict(self.inputConnectionsStore)
        self.drawGUI()
    def handleInputsworkflow(self, value, *args):
        if args and len(args) > 0: 
            self.handleInputs("workflow", value, args[0][0], test=args[0][3])
        else:
            self.handleInputs("inputFile", value, None, False)
    def handleInputsstop_metrics(self, value, *args):
        if args and len(args) > 0: 
            self.handleInputs("stop_metrics", value, args[0][0], test=args[0][3])
        else:
            self.handleInputs("inputFile", value, None, False)

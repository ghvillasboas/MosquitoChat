Mosquito Messager (MQTT Chat)
=============

This is a proof of concept of a MQTT based chat app writen for iOS.

It integrates an Open Source implementation of a MQTT Broker, called Mosquito (http://mosquitto.org/) deployed on a local network for fast and performant message exchange.

For the messaging UI, we used JSQMessages in which is a friendly and Apple's iMessage like UI implementation done with UICollectionViews (https://github.com/jessesquires/JSQMessagesViewController).

Also, we use a Twitter integration to get you info like fullname and avatar image.

To run it, clone this repository and run the command:

    pod install

In our tests, we deployed our own MQTT broker. But out of the box, we're using Eclipse.org (iot.eclipse.org)
Please be gentile and don't abuse their service.

Screenshots:

![Mosquito Chat Screenshots](https://raw.github.com/ghvillasboas/MosquitoChat/master/images/mosquitoChat.png)

## Questions?

Just fire an Issue or give me a pull request.

## Contributions?

Fire me a Pull Request!

Enjoy! ;)
## Installation

### Download and unzip
Download the plugin and unzip it into a folder of your choosing. The folder does not need to be in the OBS folders and can be located anywhere.

### Create Lichess.org API Access Token
An API access token will allow the lua script to access your user information.
The lua script requires 2 permissions: `challenger:read` and `board:play`.

The `challenger:read` permission allows the script to view the list of challengers and pull out the first (or up next) challenger.

The `board:play` permission is used by the script to recieve the event stream for a player. The script looks for the following event types:

| Type | Use |
|===|===|
| `gameStart` | Fetch and display next challenger |
| `challengeCanceled` | Fetch next challenger if current next challenger cancelled the challenge|
| `challenge` | Displays challenger if no challenge exists, increment challenger count|

![token permissions screen](https://github.com/mattrobineau/obs-lichess-next-challenger/screenshots/token_creation.png)

Copy the token string and keep it handy for the next part. If you lose or forget the token string, its gone FOREVER!!!. But you can easily create a new one so it's not the end of the world.

### Add script to OBS

In OBS, go to `Tools -> Scripts`. Press the + (plus) on the bottom left and select the `obs-lichess-next-challenger.lua` script.

Once loaded, fill in the properties:

![OBS properties screen](https://github.com/mattrobineau/obs-lichess-next-challenger/screenshots/obs_setup.png)

#### Text Source
Select a text source to use for displaying the message. (Must be a text source)

#### Personal Access Token
Add the lichess token we previously created.

#### Template
The template for the text to dispaly.

You can put any text you would like. In the screenshot's example, we are using `next: %s` where `%s` is the location to play the username.

For example, if user mattrobineau is up next, you will see `next: mattrobineau` in the text source on the stream.

## Notes
- The challenger name is updated every 10s but doesn't not call out to the lichess api.
- An active connection to the lichess `event` stream is used to update the challenger name in the internal state when it changes.
- Disabling the Source will disconnect from the lichess api stream. (Enabling/Activating the source will reconnect to the lichess api)
- If the token is missing, the source will display `Error: token`


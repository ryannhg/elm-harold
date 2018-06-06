// Load Harold
const { Elm } = require('./dist/harold')
const Harold = Elm.Main.worker()

// Set up console input
const readline = require('readline')
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  prompt: `You: `,
  terminal: false
})

// Define valid messages
const FROM_HAROLD = {
  SAY: 'SAY',
  SET_USER_PROMPT: 'SET_USER_PROMPT',
  GOODBYE: 'GOODBYE'
}
const TO_HAROLD = {
  READY: 'READY',
  SAY: 'SAY'
}

// Send Harold all the messages!
rl.on('line', (line) => Harold.ports.toHarold.send([ TO_HAROLD.SAY, line.trim() ]))
  .on('close', () => process.exit(0))

// Listen for Harold's responses
Harold.ports.fromHarold.subscribe(([ action, payload ]) => {
  switch (action) {
    case FROM_HAROLD.SAY:
      console.log(payload)
      rl.prompt()
      return

    case FROM_HAROLD.GOODBYE:
      console.log(payload)
      rl.close()
      return

    case FROM_HAROLD.SET_USER_PROMPT:
      rl.setPrompt(payload)
      return

    default:
      console.log(`I am drunk. ${action}!`)
      rl.close()
  }
})

// Begin conversation
console.clear()
Harold.ports.toHarold.send([ TO_HAROLD.READY, '' ])

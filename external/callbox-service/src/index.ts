import * as Sentry from '@sentry/node';
import fetch from 'node-fetch';
import Twilio from 'twilio';
import {ServerlessFunctionSignature} from '@twilio-labs/serverless-runtime-types/types';
import VoiceResponse from 'twilio/lib/twiml/VoiceResponse';

Sentry.init({
  dsn: 'https://2f93a9000711464a8c6fa4f19563c612@o126623.ingest.sentry.io/5391542',
});

const ENDPOINT_URL = 'https://hass.evanpurkhiser.com/api/appdaemon';

/**
 * The number of the aparment callbox.
 *
 * Not currently used for anything, but maybe it will be later.
 */
const CALLBOX = '+14155031506';

const NUMBER_MAP = {
  '+16159888483': {
    name: 'evan',
    number: '+13306220474',
  },
  '+16155278719': {
    name: 'joe',
    number: '+13306317370',
  },
} as const;

type RequestParameters = {
  /**
   * Number called from
   */
  Caller: string;
  /**
   * Number called
   */
  Called: keyof typeof NUMBER_MAP;
  /**
   * When authorization has been gathered, this will be present
   */
  Digits?: string;
};

type Env = {
  API_KEY: string;
};

type TriggerResponse = {
  numDigits: number;
  numRegisteredCodes: number;
  numSingleUseCodes: number;
};

type AuthResponse =
  | {status: 'denied'}
  | {
      status: 'granted';
      name: string | null;
      visitNumber: number;
      isSingleUse: boolean;
      lastVisit: string | null;
    };

type Handler = ServerlessFunctionSignature<Env, RequestParameters>;

const unlock = (twiml: VoiceResponse) => {
  // Unlock the door with the DTMF digit 9
  twiml.pause({length: 1});
  twiml.play({digits: '9'});
};

const say = (instance: {say: VoiceResponse['say']}, m: string) => {
  const speech = instance.say('');
  speech.prosody({volume: 'x-loud'}, m);
};

/**
 * Handle when a call first comes in, and no authorization has been provded.
 */
const handleCall: Handler = async function (ctx, event, callback) {
  const target = NUMBER_MAP[event.Called];
  const twiml = new Twilio.twiml.VoiceResponse();

  const resp = await fetch(`${ENDPOINT_URL}/callbox_trigger`, {
    method: 'POST',
    body: JSON.stringify(event),
    headers: {'x-ad-access': ctx.API_KEY},
  });

  // Something is broken on the appdaemon endpoint. Log and just directly call
  // the target.
  if (!resp.ok) {
    const err = new Error('Failed to trigger callbox API');
    Sentry.captureException(err, {
      level: Sentry.Severity.Critical,
      extra: {error: resp.statusText, ...event},
    });

    await Sentry.close(2000);

    twiml.dial(target.number);
    callback(null, twiml);
    return;
  }

  const data: TriggerResponse = await resp.json();

  // When we have single use codes available, give the user more time to enter.
  const gather = twiml.gather({
    numDigits: data.numDigits,
    timeout: data.numSingleUseCodes > 0 ? 20 : 10,
    input: ['dtmf'],
  });

  say(gather, 'Enter an access code, or wait to be connected.');

  // User did not dial the an access code, call the target person
  twiml.dial(target.number);

  callback(null, twiml);
};

/**
 * Handle when authorization has been provided
 */
const handleAuth: Handler = async function (ctx, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();

  const resp = await fetch(`${ENDPOINT_URL}/callbox_auth`, {
    method: 'POST',
    body: JSON.stringify({code: event.Digits}),
    headers: {'x-ad-access': ctx.API_KEY},
  });
  const data: AuthResponse = await resp.json();

  if (data.status !== 'granted') {
    say(twiml, `Sorry, ${event.Digits.split('').join('-')} is invalid.`);
    twiml.redirect('/index');
    callback(null, twiml);
    return;
  }

  // If it's a single use code give them specific instructions to find the apartment.
  if (data.isSingleUse) {
    say(
      twiml,
      'Valid access code. Apartment 3-0-1 is on floor 3 up the stairs to the right.'
    );
    unlock(twiml);
    callback(null, twiml);
    return;
  }

  // Welcome the user differently depending on if a name is configured for this
  // registered acess code.
  say(twiml, data.name !== null ? `Welcome ${data.name}` : 'Welcome in');

  // Tell them where the door is
  if (data.visitNumber === 1) {
    say(twiml, 'Find apartment 3-0-1 on floor 3 up the stairs to the right.');
  }

  unlock(twiml);
  callback(null, twiml);
};

export const handler: Handler = async (ctx, event, callback) =>
  event.Digits === undefined
    ? handleCall(ctx, event, callback)
    : handleAuth(ctx, event, callback);

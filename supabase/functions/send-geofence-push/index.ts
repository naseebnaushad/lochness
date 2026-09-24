// Sends an FCM push for a single geofence_events row (arrival/departure) to
// every other member of the place's circle, so the alert reaches a device
// even if the app is fully killed.
//
// Invoked by the `geofence_events_push_trigger` Postgres trigger (see
// supabase/migrations/0004_push_notifications.sql) via pg_net, with body
// `{ "record": <geofence_events row> }`.
//
// Required secrets (set with `supabase secrets set` before deploying):
//   FCM_PROJECT_ID    - Firebase project id
//   FCM_CLIENT_EMAIL  - service account client_email
//   FCM_PRIVATE_KEY   - service account private_key (PEM, \n-escaped is fine)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically by
// the Supabase Functions runtime.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;
const FCM_CLIENT_EMAIL = Deno.env.get("FCM_CLIENT_EMAIL")!;
const FCM_PRIVATE_KEY = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(): Promise<string> {
  const key = await importPrivateKey(FCM_PRIVATE_KEY);
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: FCM_CLIENT_EMAIL,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
    },
    key,
  );

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Failed to get FCM access token: ${JSON.stringify(data)}`);
  }
  return data.access_token as string;
}

serve(async (req) => {
  try {
    const { record } = await req.json();
    if (!record?.place_id || !record?.user_id || !record?.event_type) {
      return new Response("Missing/invalid record", { status: 400 });
    }

    const { data: place } = await supabase
      .from("places")
      .select("name, circle_id")
      .eq("id", record.place_id)
      .single();
    if (!place) return new Response("Place not found", { status: 200 });

    const { data: actor } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", record.user_id)
      .single();

    const { data: members } = await supabase
      .from("circle_members")
      .select("user_id")
      .eq("circle_id", place.circle_id)
      .neq("user_id", record.user_id);
    if (!members || members.length === 0) {
      return new Response("No recipients", { status: 200 });
    }

    const { data: tokens } = await supabase
      .from("device_push_tokens")
      .select("token")
      .in("user_id", members.map((m: { user_id: string }) => m.user_id));
    if (!tokens || tokens.length === 0) {
      return new Response("No tokens", { status: 200 });
    }

    const personName = actor?.display_name ?? "Someone";
    const isArrival = record.event_type === "arrival";
    const title = `${personName} ${isArrival ? "Arrived" : "Left"} ${place.name}`;
    const body = `${personName} just ${isArrival ? "arrived at" : "left"} ${place.name}`;
    const accessToken = await getAccessToken();

    await Promise.all(
      tokens.map(async (t: { token: string }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                notification: { title, body },
                data: {
                  type: "geofence_event",
                  placeId: record.place_id,
                  eventType: record.event_type,
                },
              },
            }),
          },
        );

        if (!res.ok) {
          const errorBody = await res.json().catch(() => null);
          console.error(`FCM send failed for token ${t.token}:`, res.status, errorBody);
          const status = errorBody?.error?.status;
          if (res.status === 404 || status === "UNREGISTERED" || status === "NOT_FOUND") {
            // Token belongs to an uninstalled app / stale registration.
            await supabase.from("device_push_tokens").delete().eq("token", t.token);
          }
        }
      }),
    );

    return new Response("ok", { status: 200 });
  } catch (error) {
    console.error(error);
    return new Response(String(error), { status: 500 });
  }
});

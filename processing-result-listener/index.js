// index.js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

export const handler = async (event) => {
  try {
    console.log("Received SQS Event:", JSON.stringify(event));

    for (const record of event.Records) {
      const body = JSON.parse(record.body);
      const { processing_time, s3_key_output, duration } = body;

      const parts = s3_key_output.split("/");
      const episode_id = parts[parts.length - 2];

      const { error } = await supabase
        .from('episode_audio')
        .insert([
          {
            episode_id,
            s3_path: s3_key_output,
            duration,
            processing_time
          }
        ]);

      if (error) {
        console.error("Insert error:", error);
        throw error;
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Data inserted successfully" })
    };

  } catch (err) {
    console.error("Handler error:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message })
    };
  }
};

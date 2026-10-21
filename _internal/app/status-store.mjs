import { writeFile, rename } from 'node:fs/promises';

// A brief Windows file lock must never take down the connection monitor.
export async function writeStatus(output, state, io = { writeFile, rename }) {
  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      await io.writeFile(output + '.tmp', JSON.stringify({ updated: Date.now(), ...state }));
      await io.rename(output + '.tmp', output);
      return true;
    } catch (error) {
      if (!['EPERM', 'EACCES', 'EBUSY'].includes(error.code)) throw error;
      await new Promise(resolve => setTimeout(resolve, 25 * (attempt + 1)));
    }
  }
  return false;
}

import { z } from 'zod';

import { sendMessageTool } from './tools/send_message.js';
import { readMessagesTool } from './tools/read_messages.js';
import { broadcastTool } from './tools/broadcast.js';
import { startSessionTool } from './tools/start_session.js';
import { endSessionTool } from './tools/end_session.js';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

export function createMcpServer() {
  const server = new McpServer({
    name: 'swarm-mcp',
    version: '1.0.0',
  });

  // registerTool() (not tool()) is required to pass a Zod instance as inputSchema.
  // Passthrough lets each tool handler own its own Zod validation.
  const passthroughSchema = z.object({}).passthrough();

  server.registerTool(
    sendMessageTool.name,
    { description: sendMessageTool.description, inputSchema: passthroughSchema },
    async (args) => {
      const result = await sendMessageTool.handler(args);
      return {
        content: [{ type: 'text', text: JSON.stringify(result) }],
      };
    },
  );

  server.registerTool(
    readMessagesTool.name,
    { description: readMessagesTool.description, inputSchema: passthroughSchema },
    async (args) => {
      const result = await readMessagesTool.handler(args);
      return {
        content: [{ type: 'text', text: JSON.stringify(result) }],
      };
    },
  );

  server.registerTool(
    broadcastTool.name,
    { description: broadcastTool.description, inputSchema: passthroughSchema },
    async (args) => {
      const result = await broadcastTool.handler(args);
      return {
        content: [{ type: 'text', text: JSON.stringify(result) }],
      };
    },
  );

  server.registerTool(
    startSessionTool.name,
    { description: startSessionTool.description, inputSchema: passthroughSchema },
    async (args) => {
      const result = await startSessionTool.handler(args);
      return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    },
  );

  server.registerTool(
    endSessionTool.name,
    { description: endSessionTool.description, inputSchema: passthroughSchema },
    async (args) => {
      const result = await endSessionTool.handler(args);
      return { content: [{ type: 'text', text: JSON.stringify(result) }] };
    },
  );

  return server;
}

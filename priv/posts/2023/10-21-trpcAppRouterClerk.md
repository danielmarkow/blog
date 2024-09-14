%{
title: "Set up tRPC in Next JS with App Router and Clerk",
author: "Daniel Markow",
description: "Tutorial to set up tRPC in Next JS with App Router and Clerk"
}

---

Update: Create-t3-app does the basic setup of tRPC with the app router as well now - [Link](https://www.youtube.com/watch?v=PmBfq-SpzCU)

tRPC is a wonderful framework that leverages having back- and frontend in the same language by creating type-safe remote procedure calls. If you change something in the backend procedure - adding an input field for example - typescript in the frontend will tell you so immediately with the famous red quiggly lines. Setting things up can be kind of tricky though. Since the introduction of react server components everything in the react-world is in movement. This setup seems to be approaching a relatively steady state.

To get started first create a new Next JS app by running

```bash
pnpx create-next-app@latest
```

You want to choose typescript, the app router and the src directory in order to make this tutorial work.

Next install the tRPC dependencies:

```bash
pnpm install @trpc/client @trpc/react-query @trpc/server @tanstack/react-query zod
```

And Clerk:

```bash
pnpm install @clerk/nextjs
```

At this point go to [clerk.com](http://clerk.com) and create a new project (its free). Set up the environment variables as described there. Take a look at how middleware.ts needs to be implemented in their documentation as well.

Then create a folder _trpc in the src/app directory (folders starting with “_” will be ignored by the router). Here we are going to define our tRPC client and provider.

```tsx
// client.ts
import { createTRPCReact } from "@trpc/react-query";
import type { AppRouter } from "@/server";

export const trpc = createTRPCReact<AppRouter>({});
```

```tsx
// Provider.ts
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { httpBatchLink } from "@trpc/react-query";
import React, { useState } from "react";

import { trpc } from "./client";

const API_URL = process.env.NEXT_PULIC_API_KEY;

export default function Provider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({}));
  const [trpcClient] = useState(() =>
    trpc.createClient({
      links: [
        httpBatchLink({
          url: `${API_URL}/trpc`,
        }),
      ],
    })
  );

  return (
    <trpc.Provider client={trpcClient} queryClient={queryClient}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </trpc.Provider>
  );
}
```

We will use the provider to wrap the tRPC context around the root of our component structure. This will enable us to make queries in our components. See below for how the provider is used in the top level layout file:

```tsx
import { ClerkProvider } from "@clerk/nextjs";
import Provider from "./_trpc/Provider";
import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "tRPC Tutorial",
  description: "Move fast and break nothing",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="h-full bg-white">
      <ClerkProvider>
        <body className="h-full">
          <Provider>{children}</Provider>
        </body>
      </ClerkProvider>
    </html>
  );
}
```

As you might have noticed I have already wrapped the Clerk provider as well. It provides an authentication context to the application.

Next step is to create an API route, that will handle the tRPC requests. To do that create api/trpc/[trpc]/route.ts in src/app.

```tsx
// api/trpc/[trpc]/route.ts

import { fetchRequestHandler } from "@trpc/server/adapters/fetch";
import { appRouter } from "@/server";
import { createTRPCContext } from "@/server/trpc";
import { NextRequest } from "next/server";

const handler = (req: NextRequest) =>
  fetchRequestHandler({
    endpoint: "/api/trpc",
    req,
    router: appRouter,
    createContext: () => createTRPCContext({ req }),
  });

export { handler as GET, handler as POST };
```

The createTRPCContext function passes a context to each request containing our database connection as well as the Clerk user session. It enables us to create protected procedures that may only be requested if you are logged in. It also provides the user ID and other information like organization membership conveniently on the backend.

To do all that we are going to create a new folder in src called server. It will contain

- routers (folder)
  - test.ts → this a just a test router to verify everything works as expected
- index.ts → this consolidates our routes into the appRouter which is passed to the route handler in api/trpc/[trpc]/route.ts
- trpc.ts → generates the router and its context

The implementation of the test router. The protected procedure should only be reachable when the user is authenticated.

```tsx
// test.ts
import { publicProcedure, protectedProcedure, router } from "../trpc";

export const testRouter = router({
  getTest: publicProcedure.query(async () => {
    return [1, 2, 3];
  }),
  getProtectedTest: protectedProcedure.query(async () => {
    return [4, 5, 6];
  }),
});
```

The test route is added to the app router.

```tsx
// index.ts
import { testRouter } from "./routers/test";
import { router } from "./trpc";

export const appRouter = router({
  test: testRouter,
});

export type AppRouter = typeof appRouter;
```

This initializes tRPC and adds the context to it. Next to the Clerk session you will notice my db connection (in this case I use drizzle ORM).

```tsx
// trpc.ts
import type { inferAsyncReturnType } from "@trpc/server";
import { getAuth } from "@clerk/nextjs/server";
import { db } from "@/db/db";

export const createTRPCContext = (opts: { req: NextRequest }) => {
  const session = getAuth(opts.req);

  return {
    db,
    session,
  };
};

export type Context = inferAsyncReturnType<typeof createTRPCContext>;

import { initTRPC, TRPCError } from "@trpc/server";
import { NextRequest } from "next/server";

const t = initTRPC.context<Context>().create();

const isAuthed = t.middleware(({ next, ctx }) => {
  if (!ctx.session.userId) {
    throw new TRPCError({
      code: "UNAUTHORIZED",
    });
  }

  return next({
    ctx: {
      session: ctx.session,
    },
  });
});

export const router = t.router;
export const publicProcedure = t.procedure;
export const protectedProcedure = t.procedure.use(isAuthed);
```

Congratulation. You have now successfully set up tRPC with Clerk in the Next JS App router. You may now query the test router like so:

```tsx
// ... react component

const getTest = trpc.test.getTest.useQuery();

// ...
if (getTest.isSuccess) return <>{getTest.data}</>;
```

For further information see

- A very helpful video by Jack Herrington - [Link](https://youtu.be/qCLV0Iaq9zU?si=rJiLh-FIrv-iqvwL)
- tRPC documentation - [Link](https://trpc.io/)

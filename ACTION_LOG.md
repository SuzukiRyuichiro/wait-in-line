## Action Log

This is a hand written note to myself and the evaluator for this test. I will note down the things I've done to work on this project.

### Nov 6

I first read the README thoroughly and started to brain storm what are the user stories, edge cases, do I have to think of deploying to prod or if it works on local that's fine, kinds of questions. Then, I picked a stack, overall plan on how to handle the queue logic and notifying the parties, and started writing the user sotires. In the user stories, I also added expected error cases and how the app should handle those cases. Then, I used Claude Design to visualize if the app looks good or intuitive based on that user stories. 

I assumed a few things. Things like, in Japan, apps like AirWait is somewhat prevalent, and they expect people to come on-site to print the paper out, or interact with the app on-site to queue up. However, I will assume for this project that people with the link can queue up as long as they know the URL. People could spam queue up potentially, but that's outside of this projects scope I assumed. I like when shops allow me to queue up from home too so (my barber shop does that and I like the fact I don't have to wait on-site, but I'm too lazy to book too lol)

After the design looks ok to me, and helped me to understand the flow of the app visually, I wrote the ERD.

### Nov 7

I've planned the routes, setups, potential ways to deploy, I've made a tiny grey area decision on using the DaisyUI CDN just to utilize the components. It is no JS framework so I thought it'd be alright.

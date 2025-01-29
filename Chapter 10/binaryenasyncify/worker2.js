onmessage = async (e) => {
    e.data.port.onmessage = async (e) => { 
        const sharedBuffer = e.data.sharedBuffer;
        const sharedArray = new Int32Array(sharedBuffer);
        const duration = e.data.timeout;

        console.log('worker 2 received message with duration', duration);
        await new Promise(resolve => setTimeout(() => resolve(), duration * 1000));
        console.log('worker 2 finished, notifying in shared array buffer');
        Atomics.store(sharedArray, 0, 1);
        Atomics.notify(sharedArray, 0, 1);
    }
};
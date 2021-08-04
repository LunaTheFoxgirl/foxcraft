module engine.utils.threadpool;
import core.thread;
import core.sync.mutex;
import std.algorithm.mutation : remove;

/**
    A thread pool
*/
class ThreadPool {
private:
    size_t maxThreads = 32;
    Mutex tpMutex;

    /**
        Threads in the pool
    */
    Thread[] threads;

    /**
        Queue of threads to be processed
    */
    Thread[] queue;

public:

    /**
        Creates a new thread pool
    */
    this() {
        tpMutex = new Mutex();
        threads.length = maxThreads;
    }

    /**
        Enqueues thread in pool
    */
    void enqueue(Thread thread) {
        tpMutex.lock();
            queue ~= thread;
        tpMutex.unlock();
    }

    /**
        Update the thread pool
    */
    void update() {

        tpMutex.lock();
            // Clear old threads
            for (int i; i < threads.length; i++) {
                if (threads[i] is null) continue;

                if (!threads[i].isRunning) {
                    threads[i] = null;
                }
            }

            for (int i; i < threads.length; i++) {
                if (threads[i] is null && queue.length > 0) {
                    threads[i] = queue[0];
                    threads[i].start();

                    // Remove from queue
                    queue = remove(queue, 0);
                }
            }
        
        tpMutex.unlock();
    }

}
<?php

namespace App\Controller;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class Health
{
    /**
     * @Route("/health")
     */
    public function __invoke()
    {
        return new Response('', Response::HTTP_OK);
    }
}
